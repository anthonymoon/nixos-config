#!/usr/bin/env python3
"""
Real-Time Agent Monitoring System for NixOS Installation
Provides intelligent monitoring, pattern recognition, and automated responses
"""

import subprocess
import threading
import time
import json
import re
import os
import sys
from datetime import datetime
from typing import Dict, List, Optional, Callable
from dataclasses import dataclass
from enum import Enum
import signal

# Import self-healing capabilities
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
try:
    from self_healing import SelfHealer
except ImportError:
    # Fallback if self-healing module not available
    class SelfHealer:
        def __init__(self, *args): pass
        def attempt_healing(self, *args): return False
        def get_healing_summary(self): return {}

class EventType(Enum):
    PHASE = "PHASE"
    SUCCESS = "SUCCESS"
    ERROR = "ERROR"
    WARNING = "WARNING"
    CONTEXT = "CONTEXT"
    PROGRESS = "PROGRESS"
    METRIC = "METRIC"

class InstallationPhase(Enum):
    INITIALIZATION = "INITIALIZATION"
    VM_PREPARATION = "VM_PREPARATION"
    VM_STARTUP = "VM_STARTUP"
    CONFIG_DEPLOYMENT = "CONFIG_DEPLOYMENT"
    INSTALLER_PREPARATION = "INSTALLER_PREPARATION"
    INSTALLATION_EXECUTION = "INSTALLATION_EXECUTION"
    DISK_PARTITIONING = "DISK_PARTITIONING"
    DISKO_PARTITIONING = "DISKO_PARTITIONING"
    FILESYSTEM_MOUNTING = "FILESYSTEM_MOUNTING"
    NIXOS_INSTALLATION = "NIXOS_INSTALLATION"
    POST_INSTALL_CLEANUP = "POST_INSTALL_CLEANUP"
    REBOOT_WAIT = "REBOOT_WAIT"
    SYSTEM_VERIFICATION = "SYSTEM_VERIFICATION"

@dataclass
class Event:
    timestamp: datetime
    event_type: EventType
    phase: Optional[InstallationPhase]
    message: str
    context: Dict = None

@dataclass
class SystemMetrics:
    memory_usage: Optional[int] = None
    disk_usage: Dict[str, int] = None
    network_status: Optional[str] = None
    last_updated: Optional[datetime] = None

class Pattern:
    def __init__(self, regex: str, action: Callable, description: str):
        self.regex = re.compile(regex, re.IGNORECASE)
        self.action = action
        self.description = description

class AgentMonitor:
    def __init__(self, profile: str, vm_ip: str = None, config_path: str = None):
        self.profile = profile
        self.vm_ip = vm_ip
        self.config_path = config_path or "/tmp/nixos-config"
        self.events: List[Event] = []
        self.current_phase = None
        self.metrics = SystemMetrics()
        self.start_time = datetime.now()
        self.is_running = False
        self.patterns: List[Pattern] = []
        self.error_count = 0
        self.warning_count = 0
        self.phase_start_times = {}
        self.healing_enabled = True
        self.healing_attempts = 0
        self.max_healing_attempts = 3
        
        # Initialize self-healing if VM IP available
        self.healer = None
        if vm_ip:
            try:
                self.healer = SelfHealer(vm_ip, self.config_path)
                print(f"🤖 Self-healing enabled for VM: {vm_ip}")
            except Exception as e:
                print(f"⚠️  Self-healing initialization failed: {e}")
        
        # Setup logging
        self.log_file = f"/tmp/nixos-testing/logs/agent_monitor_{profile}_{int(time.time())}.json"
        os.makedirs(os.path.dirname(self.log_file), exist_ok=True)
        
        self.setup_patterns()
        self.setup_signal_handlers()
    
    def setup_signal_handlers(self):
        """Setup graceful shutdown handlers"""
        signal.signal(signal.SIGINT, self.shutdown)
        signal.signal(signal.SIGTERM, self.shutdown)
    
    def shutdown(self, signum=None, frame=None):
        """Graceful shutdown with summary report"""
        print(f"\n🛑 Agent monitor shutting down...")
        self.is_running = False
        self.save_final_report()
        sys.exit(0)
    
    def setup_patterns(self):
        """Setup intelligent pattern recognition for automated responses"""
        
        # Error patterns with automated responses
        self.patterns.extend([
            Pattern(
                r"No suitable.*disk found",
                self.handle_disk_detection_failure,
                "Disk detection failure - attempt recovery"
            ),
            Pattern(
                r"Disko partitioning failed",
                self.handle_disko_failure,
                "Disko partitioning failure - diagnose disk issues"
            ),
            Pattern(
                r"Failed to download.*nixpkgs",
                self.handle_download_failure,
                "Download failure - suggest mirror fallback"
            ),
            Pattern(
                r"DISK_USAGE_HIGH::.*::(\d+)%",
                self.handle_high_disk_usage,
                "High disk usage detected"
            ),
            Pattern(
                r"MEMORY_USAGE_HIGH::(\d+)%",
                self.handle_high_memory_usage,
                "High memory usage detected"
            ),
            Pattern(
                r"NETWORK_CONNECTIVITY_FAILED",
                self.handle_network_failure,
                "Network connectivity issues"
            ),
            Pattern(
                r"installation completed successfully",
                self.handle_installation_success,
                "Installation completed successfully"
            ),
        ])
    
    def log_event(self, event: Event):
        """Log event to memory and file"""
        self.events.append(event)
        
        # Write to JSON log file
        with open(self.log_file, 'a') as f:
            json.dump({
                'timestamp': event.timestamp.isoformat(),
                'type': event.event_type.value,
                'phase': event.phase.value if event.phase else None,
                'message': event.message,
                'context': event.context or {}
            }, f)
            f.write('\n')
    
    def parse_structured_output(self, line: str) -> Optional[Event]:
        """Parse structured output from stream runner"""
        if match := re.match(r'^::([A-Z_]+)::(.*)$', line.strip()):
            event_type_str, message = match.groups()
            
            try:
                event_type = EventType(event_type_str)
            except ValueError:
                return None
            
            # Determine phase if this is a PHASE event
            phase = None
            if event_type == EventType.PHASE:
                try:
                    phase = InstallationPhase(message)
                    self.current_phase = phase
                    self.phase_start_times[phase] = datetime.now()
                except ValueError:
                    pass
            
            return Event(
                timestamp=datetime.now(),
                event_type=event_type,
                phase=phase or self.current_phase,
                message=message
            )
        
        return None
    
    def process_line(self, line: str):
        """Process a single line of output with intelligence"""
        
        # Try to parse as structured output first
        event = self.parse_structured_output(line)
        if event:
            self.log_event(event)
            self.display_event(event)
            
            # Update counters
            if event.event_type == EventType.ERROR:
                self.error_count += 1
            elif event.event_type == EventType.WARNING:
                self.warning_count += 1
        
        # Apply pattern matching for automated responses
        for pattern in self.patterns:
            if match := pattern.regex.search(line):
                print(f"🤖 Pattern matched: {pattern.description}")
                try:
                    # First try traditional pattern action
                    pattern.action(match, line)
                    
                    # If this is an error pattern and healing is enabled, attempt healing
                    if (event and event.event_type == EventType.ERROR and 
                        self.healing_enabled and self.healer and 
                        self.healing_attempts < self.max_healing_attempts):
                        
                        print(f"🔬 Attempting self-healing (attempt {self.healing_attempts + 1}/{self.max_healing_attempts})")
                        
                        if self.healer.attempt_healing(line, context=str(event.context or {})):
                            print("✨ Self-healing successful! Continuing installation...")
                            self.healing_attempts += 1
                            
                            # Log successful healing
                            self.log_event(Event(
                                timestamp=datetime.now(),
                                event_type=EventType.SUCCESS,
                                phase=self.current_phase,
                                message=f"SELF_HEALING_SUCCESS::attempt_{self.healing_attempts}",
                                context={"original_error": line}
                            ))
                        else:
                            print("💔 Self-healing failed")
                            self.healing_attempts += 1
                            
                            # Log failed healing
                            self.log_event(Event(
                                timestamp=datetime.now(),
                                event_type=EventType.WARNING,
                                phase=self.current_phase,
                                message=f"SELF_HEALING_FAILED::attempt_{self.healing_attempts}",
                                context={"original_error": line}
                            ))
                            
                except Exception as e:
                    print(f"❌ Error in pattern action: {e}")
    
    def display_event(self, event: Event):
        """Display event with appropriate formatting"""
        timestamp = event.timestamp.strftime("%H:%M:%S")
        
        colors = {
            EventType.PHASE: "\033[96m",      # Cyan
            EventType.SUCCESS: "\033[92m",    # Green
            EventType.ERROR: "\033[91m",      # Red
            EventType.WARNING: "\033[93m",    # Yellow
            EventType.CONTEXT: "\033[94m",    # Blue
            EventType.PROGRESS: "\033[95m",   # Magenta
            EventType.METRIC: "\033[90m",     # Dark Gray
        }
        
        icons = {
            EventType.PHASE: "📍",
            EventType.SUCCESS: "✅",
            EventType.ERROR: "❌",
            EventType.WARNING: "⚠️",
            EventType.CONTEXT: "ℹ️",
            EventType.PROGRESS: "⏳",
            EventType.METRIC: "📊",
        }
        
        color = colors.get(event.event_type, "\033[0m")
        icon = icons.get(event.event_type, "•")
        reset = "\033[0m"
        
        print(f"{color}{timestamp} {icon} {event.event_type.value}: {event.message}{reset}")
    
    # Automated response handlers
    def handle_disk_detection_failure(self, match, line):
        """Handle disk detection failures with automated diagnosis"""
        print("🔧 AUTOMATED RESPONSE: Disk detection failure")
        print("   → Suggested action: Check VM disk configuration")
        print("   → Alternative: Specify disk device manually in disko-config.nix")
        
        # Log automated response suggestion
        self.log_event(Event(
            timestamp=datetime.now(),
            event_type=EventType.CONTEXT,
            phase=self.current_phase,
            message="AUTOMATED_SUGGESTION::Check VM disk attachment and device naming",
            context={"trigger": "disk_detection_failure", "line": line}
        ))
    
    def handle_disko_failure(self, match, line):
        """Handle Disko partitioning failures"""
        print("🔧 AUTOMATED RESPONSE: Disko partitioning failure")
        print("   → Checking disk status...")
        print("   → Suggestion: Verify disk is attached and writable")
        
        self.log_event(Event(
            timestamp=datetime.now(),
            event_type=EventType.CONTEXT,
            phase=self.current_phase,
            message="AUTOMATED_SUGGESTION::Verify disk attachment and permissions",
            context={"trigger": "disko_failure", "line": line}
        ))
    
    def handle_download_failure(self, match, line):
        """Handle download failures with mirror suggestions"""
        print("🔧 AUTOMATED RESPONSE: Download failure detected")
        print("   → Suggestion: Check network connectivity")
        print("   → Alternative: Try different Nix cache mirror")
        
        self.log_event(Event(
            timestamp=datetime.now(),
            event_type=EventType.CONTEXT,
            phase=self.current_phase,
            message="AUTOMATED_SUGGESTION::Check network or try alternative mirror",
            context={"trigger": "download_failure", "line": line}
        ))
    
    def handle_high_disk_usage(self, match, line):
        """Handle high disk usage warnings"""
        usage = match.group(1)
        print(f"🔧 AUTOMATED RESPONSE: High disk usage detected ({usage}%)")
        print("   → Monitoring disk space...")
        
        if int(usage) > 95:
            print("   → CRITICAL: Disk space critically low!")
            print("   → Suggestion: Increase VM disk size or clean up space")
    
    def handle_high_memory_usage(self, match, line):
        """Handle high memory usage warnings"""
        usage = match.group(1)
        print(f"🔧 AUTOMATED RESPONSE: High memory usage detected ({usage}%)")
        
        if int(usage) > 95:
            print("   → CRITICAL: Memory critically low!")
            print("   → Suggestion: Increase VM memory allocation")
    
    def handle_network_failure(self, match, line):
        """Handle network connectivity failures"""
        print("🔧 AUTOMATED RESPONSE: Network connectivity failure")
        print("   → Suggestion: Check VM network configuration")
        print("   → Alternative: Verify host network connectivity")
    
    def handle_installation_success(self, match, line):
        """Handle successful installation completion"""
        duration = datetime.now() - self.start_time
        print(f"🎉 INSTALLATION SUCCESS in {duration}")
        print(f"   → Profile: {self.profile}")
        print(f"   → Duration: {duration}")
        print(f"   → Errors: {self.error_count}")
        print(f"   → Warnings: {self.warning_count}")
    
    def monitor_stream(self, process):
        """Monitor subprocess output in real-time"""
        print(f"🤖 Agent monitoring started for profile: {self.profile}")
        print(f"📝 Logging to: {self.log_file}")
        print("=" * 60)
        
        self.is_running = True
        
        for line in iter(process.stdout.readline, b''):
            if not self.is_running:
                break
                
            line = line.decode('utf-8').rstrip()
            if line:
                self.process_line(line)
        
        # Wait for process completion
        process.wait()
        return process.returncode
    
    def save_final_report(self):
        """Save final analysis report"""
        duration = datetime.now() - self.start_time
        
        # Calculate phase durations
        phase_durations = {}
        phases = list(self.phase_start_times.keys())
        for i, phase in enumerate(phases):
            start_time = self.phase_start_times[phase]
            end_time = self.phase_start_times[phases[i + 1]] if i + 1 < len(phases) else datetime.now()
            phase_durations[phase.value] = (end_time - start_time).total_seconds()
        
        # Get healing summary if available
        healing_summary = {}
        if self.healer:
            healing_summary = self.healer.get_healing_summary()
        
        report = {
            'profile': self.profile,
            'start_time': self.start_time.isoformat(),
            'duration_seconds': duration.total_seconds(),
            'total_events': len(self.events),
            'error_count': self.error_count,
            'warning_count': self.warning_count,
            'phase_durations': phase_durations,
            'healing_attempts': self.healing_attempts,
            'healing_summary': healing_summary,
            'status': 'success' if self.error_count == 0 else 'failed'
        }
        
        report_file = f"/tmp/nixos-testing/logs/final_report_{self.profile}_{int(time.time())}.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"\n📊 Final report saved to: {report_file}")
        print(f"⏱️  Total duration: {duration}")
        print(f"📈 Events processed: {len(self.events)}")
        print(f"❌ Errors: {self.error_count}")
        print(f"⚠️  Warnings: {self.warning_count}")

def main():
    if len(sys.argv) < 3:
        print("Usage: agent-monitor.py <profile> [--vm-ip IP] <command...>")
        sys.exit(1)
    
    profile = sys.argv[1]
    vm_ip = None
    command_start = 2
    
    # Parse optional --vm-ip parameter
    if len(sys.argv) > 3 and sys.argv[2] == "--vm-ip":
        vm_ip = sys.argv[3]
        command_start = 4
    
    command = sys.argv[command_start:]
    
    monitor = AgentMonitor(profile, vm_ip=vm_ip)
    
    try:
        # Start the monitored process
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=False
        )
        
        # Monitor the stream
        exit_code = monitor.monitor_stream(process)
        
        # Save final report
        monitor.save_final_report()
        
        sys.exit(exit_code)
        
    except KeyboardInterrupt:
        print("\n🛑 Monitoring interrupted by user")
        monitor.shutdown()
    except Exception as e:
        print(f"❌ Monitor error: {e}")
        monitor.save_final_report()
        sys.exit(1)

if __name__ == "__main__":
    main()