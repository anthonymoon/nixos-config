#!/usr/bin/env python3
"""
NixOS Test Agent Monitor
Real-time stream processing and intelligent test orchestration
"""

import asyncio
import json
import logging
import re
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional, Callable, Any
import subprocess
import asyncssh

# Configuration
REPO_ROOT = Path(__file__).parent.parent.parent
ISO_PATH = REPO_ROOT / "nixos-minimal-25.05.805766.7a732ed41ca0-x86_64-linux.iso"
LOG_DIR = Path("/tmp/nixos-test-logs")
STATE_FILE = Path("/tmp/nixos-test-state.json")

# Ensure log directory exists
LOG_DIR.mkdir(exist_ok=True)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_DIR / "agent-monitor.log"),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger("NixOSTestAgent")

class TestPhase(Enum):
    """Test execution phases"""
    PROVISIONING = "provisioning"
    INSTALLATION = "installation"
    REBOOT = "reboot"
    TESTING = "testing"
    COMPLETED = "completed"
    FAILED = "failed"

class StreamEventType(Enum):
    """Types of events detected in output streams"""
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"
    PROGRESS = "progress"
    SUCCESS = "success"

@dataclass
class StreamEvent:
    """Represents an event detected in the output stream"""
    timestamp: datetime
    phase: TestPhase
    event_type: StreamEventType
    pattern: str
    message: str
    context: List[str] = field(default_factory=list)
    
@dataclass
class TestState:
    """Tracks the state of a test run"""
    profile: str
    phase: TestPhase
    start_time: datetime
    vm_name: str
    vm_ip: Optional[str] = None
    events: List[StreamEvent] = field(default_factory=list)
    errors: List[str] = field(default_factory=list)
    status: str = "running"
    
class PatternMatcher:
    """Intelligent pattern matching for stream analysis"""
    
    PATTERNS = {
        # Critical errors that should abort immediately
        "critical": [
            (r"error: Disko partitioning failed", "Disk partitioning failure"),
            (r"kernel panic", "Kernel panic detected"),
            (r"out of memory", "Out of memory error"),
            (r"CRITICAL ERROR", "Critical error flag"),
            (r"Installation failed", "Installation failure"),
        ],
        
        # Errors that might be recoverable
        "error": [
            (r"error: (.+)", "General error: {}"),
            (r"Failed to (.+)", "Failure: {}"),
            (r"Cannot (.+)", "Cannot: {}"),
        ],
        
        # Progress indicators
        "progress": [
            (r"Setting up disk partitioning", "Starting disk setup"),
            (r"Installing NixOS configuration", "Installing system"),
            (r"Building configuration", "Building NixOS"),
            (r"Installation complete", "Installation finished"),
            (r"starting VM\.\.\.", "Test VM starting"),
            (r"test script finished with exit code (\d+)", "Test completed with code {}"),
        ],
        
        # Success indicators
        "success": [
            (r"✓|Success|SUCCESS", "Success indicator"),
            (r"Installation complete", "Installation successful"),
            (r"All tests passed", "Tests passed"),
        ]
    }
    
    @classmethod
    def analyze_line(cls, line: str, phase: TestPhase) -> Optional[StreamEvent]:
        """Analyze a single line and return event if pattern matches"""
        line = line.strip()
        if not line:
            return None
            
        # Check each pattern category
        for event_type, patterns in cls.PATTERNS.items():
            for pattern, description in patterns:
                match = re.search(pattern, line)
                if match:
                    message = description
                    if '{}' in description and match.groups():
                        message = description.format(*match.groups())
                    
                    return StreamEvent(
                        timestamp=datetime.now(),
                        phase=phase,
                        event_type=StreamEventType(event_type),
                        pattern=pattern,
                        message=message,
                        context=[line]
                    )
        
        return None

class StreamProcessor:
    """Processes output streams in real-time"""
    
    def __init__(self, state: TestState, event_handler: Callable[[StreamEvent], None]):
        self.state = state
        self.event_handler = event_handler
        self.buffer = []
        self.max_buffer = 100
        
    async def process_line(self, line: str):
        """Process a single line from the stream"""
        # Add to rolling buffer
        self.buffer.append(line)
        if len(self.buffer) > self.max_buffer:
            self.buffer.pop(0)
        
        # Log the raw stream
        logger.debug(f"[STREAM] {line}")
        
        # Analyze for patterns
        event = PatternMatcher.analyze_line(line, self.state.phase)
        if event:
            event.context = self.buffer[-10:]  # Last 10 lines for context
            self.state.events.append(event)
            await self.event_handler(event)

class VMManager:
    """Manages libvirt VMs for testing"""
    
    def __init__(self, vm_name: str = "nixos-test-vm"):
        self.vm_name = vm_name
        self.conn_uri = "qemu:///system"
        
    async def create_vm(self, profile: str) -> bool:
        """Create a new VM for testing"""
        logger.info(f"Creating VM for profile: {profile}")
        
        # Check if VM exists and destroy it
        destroy_cmd = f"virsh --connect {self.conn_uri} destroy {self.vm_name} 2>/dev/null || true"
        undefine_cmd = f"virsh --connect {self.conn_uri} undefine {self.vm_name} --remove-all-storage 2>/dev/null || true"
        
        await self._run_command(destroy_cmd)
        await self._run_command(undefine_cmd)
        
        # Create disk
        disk_path = f"/var/lib/libvirt/images/{self.vm_name}.qcow2"
        create_disk = f"qemu-img create -f qcow2 {disk_path} 20G"
        await self._run_command(create_disk)
        
        # Create VM with virt-install
        create_vm = f"""
        virt-install --connect {self.conn_uri} \
            --name {self.vm_name} \
            --memory 4096 \
            --vcpus 2 \
            --disk path={disk_path},format=qcow2,bus=virtio \
            --cdrom {ISO_PATH} \
            --network network=default,model=virtio \
            --graphics vnc \
            --noautoconsole \
            --os-variant nixos-unstable \
            --boot uefi
        """
        
        result = await self._run_command(create_vm)
        if result:
            # Create snapshot
            snapshot_cmd = f"virsh --connect {self.conn_uri} snapshot-create-as {self.vm_name} clean-state 'Clean installer state'"
            await self._run_command(snapshot_cmd)
            return True
        return False
        
    async def revert_snapshot(self) -> bool:
        """Revert VM to clean snapshot"""
        cmd = f"virsh --connect {self.conn_uri} snapshot-revert {self.vm_name} clean-state"
        return await self._run_command(cmd)
        
    async def start_vm(self) -> bool:
        """Start the VM"""
        cmd = f"virsh --connect {self.conn_uri} start {self.vm_name}"
        return await self._run_command(cmd)
        
    async def discover_ip(self, timeout: int = 60) -> Optional[str]:
        """Discover VM IP address"""
        logger.info("Discovering VM IP address...")
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            cmd = f"virsh --connect {self.conn_uri} net-dhcp-leases default | grep {self.vm_name} | awk '{{print $5}}' | cut -d'/' -f1 | head -n1"
            proc = await asyncio.create_subprocess_shell(
                cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, _ = await proc.communicate()
            
            ip = stdout.decode().strip()
            if ip:
                logger.info(f"VM IP discovered: {ip}")
                return ip
                
            await asyncio.sleep(2)
            
        logger.error("Failed to discover VM IP")
        return None
        
    async def _run_command(self, cmd: str) -> bool:
        """Run a shell command"""
        proc = await asyncio.create_subprocess_shell(
            cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        _, stderr = await proc.communicate()
        
        if proc.returncode != 0 and stderr:
            logger.error(f"Command failed: {stderr.decode()}")
            return False
        return True

class TestOrchestrator:
    """Main test orchestration agent"""
    
    def __init__(self):
        self.vm_manager = VMManager()
        self.states: Dict[str, TestState] = {}
        self.current_state: Optional[TestState] = None
        
    async def test_profile(self, profile: str) -> bool:
        """Test a single profile"""
        logger.info(f"{'='*60}")
        logger.info(f"Testing profile: {profile}")
        logger.info(f"{'='*60}")
        
        # Initialize state
        state = TestState(
            profile=profile,
            phase=TestPhase.PROVISIONING,
            start_time=datetime.now(),
            vm_name=self.vm_manager.vm_name
        )
        self.states[profile] = state
        self.current_state = state
        
        try:
            # Phase 1: Provisioning
            if not await self._provision_vm(state):
                return False
                
            # Phase 2: Installation
            if not await self._run_installation(state):
                return False
                
            # Phase 3: Testing
            if not await self._run_tests(state):
                return False
                
            state.phase = TestPhase.COMPLETED
            state.status = "passed"
            logger.success(f"✅ Profile {profile} passed all tests!")
            return True
            
        except Exception as e:
            logger.error(f"Test failed with exception: {e}")
            state.phase = TestPhase.FAILED
            state.status = "failed"
            state.errors.append(str(e))
            return False
            
    async def _provision_vm(self, state: TestState) -> bool:
        """Provision VM for testing"""
        logger.info("Phase 1: Provisioning VM")
        
        # Create or revert VM
        if not await self.vm_manager.revert_snapshot():
            if not await self.vm_manager.create_vm(state.profile):
                logger.error("Failed to create VM")
                return False
                
        # Start VM
        if not await self.vm_manager.start_vm():
            logger.error("Failed to start VM")
            return False
            
        # Discover IP
        ip = await self.vm_manager.discover_ip()
        if not ip:
            return False
            
        state.vm_ip = ip
        
        # Wait for SSH
        if not await self._wait_for_ssh(ip):
            return False
            
        return True
        
    async def _run_installation(self, state: TestState) -> bool:
        """Run installation with real-time monitoring"""
        logger.info("Phase 2: Running installation")
        state.phase = TestPhase.INSTALLATION
        
        # Copy repository
        logger.info("Copying repository to VM...")
        async with asyncssh.connect(
            state.vm_ip,
            username='nixos',
            password='nixos',
            known_hosts=None
        ) as conn:
            # Copy files
            await conn.run(f'mkdir -p /tmp/nixos-config')
            # In real implementation, would use sftp to copy files
            
            # Run installation with streaming
            install_cmd = f"sudo INSTALL_PROFILE={state.profile} INSTALL_DISK=/dev/vda INSTALL_USER=testuser /tmp/nixos-config/install/install.sh"
            
            # Create stream processor
            processor = StreamProcessor(state, self._handle_event)
            
            # Run command with streaming output
            async with conn.create_process(install_cmd) as proc:
                async for line in proc.stdout:
                    await processor.process_line(line.strip())
                    
                # Wait for completion
                await proc.wait()
                
                if proc.exit_status != 0:
                    logger.error(f"Installation failed with exit code: {proc.exit_status}")
                    return False
                    
        return True
        
    async def _run_tests(self, state: TestState) -> bool:
        """Run post-installation tests"""
        logger.info("Phase 3: Running tests")
        state.phase = TestPhase.TESTING
        
        # Wait for reboot
        logger.info("Waiting for system reboot...")
        await asyncio.sleep(30)
        
        if not await self._wait_for_ssh(state.vm_ip, username='testuser'):
            return False
            
        # Run declarative tests
        async with asyncssh.connect(
            state.vm_ip,
            username='testuser',
            password='testuser',  # Set during installation
            known_hosts=None
        ) as conn:
            test_cmd = f"cd /etc/nixos && sudo nix flake check .#{state.profile}-test"
            
            processor = StreamProcessor(state, self._handle_event)
            
            async with conn.create_process(test_cmd) as proc:
                async for line in proc.stdout:
                    await processor.process_line(line.strip())
                    
                await proc.wait()
                
                if proc.exit_status != 0:
                    logger.error(f"Tests failed with exit code: {proc.exit_status}")
                    return False
                    
        return True
        
    async def _wait_for_ssh(self, ip: str, username: str = 'nixos', timeout: int = 120) -> bool:
        """Wait for SSH to become available"""
        logger.info(f"Waiting for SSH on {ip}...")
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            try:
                async with asyncssh.connect(
                    ip,
                    username=username,
                    password='nixos' if username == 'nixos' else 'testuser',
                    known_hosts=None,
                    connect_timeout=5
                ):
                    logger.info("SSH is ready")
                    return True
            except:
                await asyncio.sleep(2)
                
        logger.error("SSH timeout")
        return False
        
    async def _handle_event(self, event: StreamEvent):
        """Handle events from stream processing"""
        # Log based on event type
        if event.event_type == StreamEventType.CRITICAL:
            logger.critical(f"CRITICAL: {event.message}")
            logger.info("Context:")
            for line in event.context[-5:]:
                logger.info(f"  {line}")
            # Could trigger immediate abort here
            
        elif event.event_type == StreamEventType.ERROR:
            logger.error(f"ERROR: {event.message}")
            
        elif event.event_type == StreamEventType.SUCCESS:
            logger.success(f"SUCCESS: {event.message}")
            
        elif event.event_type == StreamEventType.PROGRESS:
            logger.info(f"PROGRESS: {event.message}")
            
        # Agent "thoughts" based on events
        if "Disko partitioning" in event.message:
            logger.thought("Critical phase: disk partitioning. Monitoring for failures...")
        elif "Installation complete" in event.message:
            logger.thought("Installation successful. Preparing for reboot and testing phase...")
        elif "test script finished" in event.message:
            logger.thought("Test execution completed. Analyzing results...")

    async def run_all_profiles(self) -> Dict[str, bool]:
        """Run tests for all profiles"""
        profiles = ["vm", "workstation", "server"]
        results = {}
        
        for profile in profiles:
            try:
                results[profile] = await self.test_profile(profile)
            except Exception as e:
                logger.error(f"Failed to test {profile}: {e}")
                results[profile] = False
                
        return results
        
    def generate_report(self) -> str:
        """Generate test report"""
        report = ["NixOS Test Report", "=" * 50, ""]
        
        for profile, state in self.states.items():
            report.append(f"Profile: {profile}")
            report.append(f"Status: {state.status}")
            report.append(f"Duration: {datetime.now() - state.start_time}")
            
            if state.errors:
                report.append("Errors:")
                for error in state.errors:
                    report.append(f"  - {error}")
                    
            report.append("")
            
        return "\n".join(report)

# Custom logger methods
def success(self, message):
    self.info(f"✅ {message}")
    
def thought(self, message):
    self.info(f"🤔 [THOUGHT] {message}")
    
# Add methods to logger
logging.Logger.success = success
logging.Logger.thought = thought

async def main():
    """Main entry point"""
    orchestrator = TestOrchestrator()
    
    # Run all tests
    results = await orchestrator.run_all_profiles()
    
    # Generate report
    report = orchestrator.generate_report()
    print("\n" + report)
    
    # Save state
    with open(STATE_FILE, 'w') as f:
        json.dump({
            profile: {
                "status": state.status,
                "errors": state.errors,
                "events": len(state.events)
            }
            for profile, state in orchestrator.states.items()
        }, f, indent=2)
    
    # Exit with appropriate code
    if all(results.values()):
        logger.success("All tests passed!")
        sys.exit(0)
    else:
        logger.error("Some tests failed!")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())