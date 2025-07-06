#!/usr/bin/env python3
"""
Self-Healing Capabilities for NixOS Installation Testing
Provides automated error recovery and configuration fixes
"""

import subprocess
import json
import re
import os
import tempfile
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from datetime import datetime

@dataclass
class HealingAction:
    name: str
    description: str
    confidence: float  # 0.0 to 1.0
    commands: List[str]
    config_changes: Dict[str, str] = None
    
class SelfHealer:
    def __init__(self, vm_ip: str, config_path: str):
        self.vm_ip = vm_ip
        self.config_path = config_path
        self.healing_log = []
        
    def log_healing_attempt(self, action: HealingAction, success: bool, output: str = ""):
        """Log healing attempts for analysis"""
        entry = {
            'timestamp': datetime.now().isoformat(),
            'action': action.name,
            'description': action.description,
            'confidence': action.confidence,
            'success': success,
            'output': output
        }
        self.healing_log.append(entry)
        
        log_file = "/tmp/nixos-testing/logs/self_healing.json"
        os.makedirs(os.path.dirname(log_file), exist_ok=True)
        
        with open(log_file, 'a') as f:
            json.dump(entry, f)
            f.write('\n')
    
    def ssh_execute(self, command: str, user: str = "nixos") -> Tuple[bool, str]:
        """Execute command on VM via SSH"""
        try:
            result = subprocess.run([
                'ssh', '-o', 'StrictHostKeyChecking=no', 
                '-o', 'UserKnownHostsFile=/dev/null',
                f'{user}@{self.vm_ip}', command
            ], capture_output=True, text=True, timeout=60)
            
            return result.returncode == 0, result.stdout + result.stderr
        except subprocess.TimeoutExpired:
            return False, "Command timed out"
        except Exception as e:
            return False, str(e)
    
    def copy_file_to_vm(self, local_path: str, remote_path: str) -> bool:
        """Copy file to VM"""
        try:
            subprocess.run([
                'scp', '-o', 'StrictHostKeyChecking=no',
                '-o', 'UserKnownHostsFile=/dev/null',
                local_path, f'nixos@{self.vm_ip}:{remote_path}'
            ], check=True, capture_output=True)
            return True
        except subprocess.CalledProcessError:
            return False
    
    def analyze_disk_detection_failure(self) -> List[HealingAction]:
        """Analyze and provide fixes for disk detection failures"""
        actions = []
        
        # Get available disks on VM
        success, output = self.ssh_execute("lsblk -d -o NAME,SIZE,TYPE | grep disk")
        
        if success and output.strip():
            disks = []
            for line in output.strip().split('\n'):
                parts = line.split()
                if len(parts) >= 3 and parts[2] == 'disk':
                    disks.append(f"/dev/{parts[0]}")
            
            if disks:
                # Create action to fix disko-config.nix with detected disks
                actions.append(HealingAction(
                    name="fix_disk_detection",
                    description=f"Update disko-config.nix to use detected disk: {disks[0]}",
                    confidence=0.9,
                    commands=[],
                    config_changes={
                        "disko-config.nix": self._generate_fixed_disko_config(disks[0])
                    }
                ))
        
        # Alternative: Use manual disk specification
        actions.append(HealingAction(
            name="manual_disk_fallback",
            description="Create simplified disko config with manual disk specification",
            confidence=0.7,
            commands=[],
            config_changes={
                "disko-config.nix": self._generate_manual_disko_config()
            }
        ))
        
        return actions
    
    def analyze_network_failure(self) -> List[HealingAction]:
        """Analyze and provide fixes for network failures"""
        actions = []
        
        # Check DNS resolution
        success, _ = self.ssh_execute("nslookup cache.nixos.org")
        if not success:
            actions.append(HealingAction(
                name="fix_dns",
                description="Configure alternative DNS servers",
                confidence=0.8,
                commands=[
                    "echo 'nameserver 8.8.8.8' | sudo tee /etc/resolv.conf",
                    "echo 'nameserver 1.1.1.1' | sudo tee -a /etc/resolv.conf"
                ]
            ))
        
        # Check network interface
        success, output = self.ssh_execute("ip link show")
        if success:
            # Look for down interfaces
            for line in output.split('\n'):
                if 'state DOWN' in line and 'eth' in line:
                    interface = line.split(':')[1].strip()
                    actions.append(HealingAction(
                        name="fix_network_interface",
                        description=f"Bring up network interface {interface}",
                        confidence=0.7,
                        commands=[f"sudo ip link set {interface} up"]
                    ))
        
        return actions
    
    def analyze_download_failure(self) -> List[HealingAction]:
        """Analyze and provide fixes for download failures"""
        actions = []
        
        # Try alternative cache servers
        actions.append(HealingAction(
            name="alternative_cache",
            description="Configure alternative Nix cache servers",
            confidence=0.8,
            commands=[],
            config_changes={
                "nix.conf": """
substituters = https://cache.nixos.org https://nix-community.cachix.org https://cache.garnix.io
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbCWpDmyhVQB+VNb8pg=
"""
            }
        ))
        
        # Retry with offline installation
        actions.append(HealingAction(
            name="offline_fallback",
            description="Attempt offline installation mode",
            confidence=0.6,
            commands=[
                "export NIXOS_CONFIG_OFFLINE=1"
            ]
        ))
        
        return actions
    
    def analyze_memory_pressure(self) -> List[HealingAction]:
        """Analyze and provide fixes for memory pressure"""
        actions = []
        
        # Enable swap if not present
        success, output = self.ssh_execute("swapon --show")
        if not success or not output.strip():
            actions.append(HealingAction(
                name="enable_emergency_swap",
                description="Create emergency swap file",
                confidence=0.8,
                commands=[
                    "sudo dd if=/dev/zero of=/tmp/emergency_swap bs=1M count=512",
                    "sudo chmod 600 /tmp/emergency_swap",
                    "sudo mkswap /tmp/emergency_swap",
                    "sudo swapon /tmp/emergency_swap"
                ]
            ))
        
        # Clean package cache
        actions.append(HealingAction(
            name="clean_cache",
            description="Clean Nix store and package cache",
            confidence=0.9,
            commands=[
                "sudo nix-collect-garbage -d",
                "sudo nix-store --optimize"
            ]
        ))
        
        return actions
    
    def analyze_disk_space_issue(self) -> List[HealingAction]:
        """Analyze and provide fixes for disk space issues"""
        actions = []
        
        # Clean temporary files
        actions.append(HealingAction(
            name="clean_temp_files",
            description="Clean temporary files and logs",
            confidence=0.9,
            commands=[
                "sudo rm -rf /tmp/*",
                "sudo journalctl --vacuum-size=100M",
                "sudo rm -rf /var/log/*.old /var/log/*/*.old"
            ]
        ))
        
        # Clean Nix store
        actions.append(HealingAction(
            name="aggressive_nix_cleanup",
            description="Aggressive Nix store cleanup",
            confidence=0.8,
            commands=[
                "sudo nix-collect-garbage --delete-older-than 1d",
                "sudo nix-store --gc",
                "sudo nix-store --optimize"
            ]
        ))
        
        return actions
    
    def _generate_fixed_disko_config(self, disk_device: str) -> str:
        """Generate fixed disko config with specific disk device"""
        return f'''# Fixed Disko configuration with detected disk
{{
  disko.devices = {{
    disk = {{
      main = {{
        type = "disk";
        device = "{disk_device}";
        content = {{
          type = "gpt";
          partitions = {{
            boot = {{
              size = "1G";
              type = "EF00";
              content = {{
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              }};
            }};
            root = {{
              size = "100%";
              content = {{
                type = "btrfs";
                mountOptions = [
                  "compress=zstd"
                  "ssd"
                  "discard=async"
                  "noatime"
                ];
                subvolumes = {{
                  "@" = {{ mountpoint = "/"; }};
                  "@home" = {{ mountpoint = "/home"; }};
                  "@nix" = {{ mountpoint = "/nix"; }};
                  "@log" = {{ mountpoint = "/var/log"; }};
                  "@snapshots" = {{}};
                }};
              }};
            }};
          }};
        }};
      }};
    }};
  }};
}}'''
    
    def _generate_manual_disko_config(self) -> str:
        """Generate simplified manual disko config"""
        return '''# Simplified manual Disko configuration
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/vda";  # Manual fallback
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}'''
    
    def attempt_healing(self, error_pattern: str, context: str = "") -> bool:
        """Main healing entry point - attempts to fix detected issues"""
        print(f"🔧 SELF-HEALING: Analyzing error pattern: {error_pattern}")
        
        actions = []
        
        # Pattern-based healing strategy selection
        if re.search(r"No suitable.*disk found", error_pattern, re.IGNORECASE):
            actions.extend(self.analyze_disk_detection_failure())
        
        elif re.search(r"network.*fail|download.*fail|connection.*fail", error_pattern, re.IGNORECASE):
            actions.extend(self.analyze_network_failure())
            actions.extend(self.analyze_download_failure())
        
        elif re.search(r"memory.*low|out of memory", error_pattern, re.IGNORECASE):
            actions.extend(self.analyze_memory_pressure())
        
        elif re.search(r"disk.*full|no space|space.*low", error_pattern, re.IGNORECASE):
            actions.extend(self.analyze_disk_space_issue())
        
        elif re.search(r"disko.*fail|partition.*fail", error_pattern, re.IGNORECASE):
            actions.extend(self.analyze_disk_detection_failure())
        
        if not actions:
            print("🤷 No healing actions available for this error pattern")
            return False
        
        # Sort actions by confidence (highest first)
        actions.sort(key=lambda x: x.confidence, reverse=True)
        
        # Attempt healing actions
        for action in actions:
            print(f"🩺 Attempting: {action.description} (confidence: {action.confidence:.1%})")
            
            success = self._execute_healing_action(action)
            self.log_healing_attempt(action, success)
            
            if success:
                print(f"✅ Healing action succeeded: {action.name}")
                return True
            else:
                print(f"❌ Healing action failed: {action.name}")
        
        print("💔 All healing attempts failed")
        return False
    
    def _execute_healing_action(self, action: HealingAction) -> bool:
        """Execute a specific healing action"""
        try:
            # Execute commands
            for command in action.commands:
                success, output = self.ssh_execute(command)
                if not success:
                    print(f"Command failed: {command}")
                    print(f"Output: {output}")
                    return False
            
            # Apply configuration changes
            if action.config_changes:
                for filename, content in action.config_changes.items():
                    # Create temporary file
                    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix=f'_{filename}') as f:
                        f.write(content)
                        temp_path = f.name
                    
                    try:
                        # Copy to VM
                        remote_path = f"/tmp/nixos-config/{filename}"
                        if self.copy_file_to_vm(temp_path, remote_path):
                            print(f"Updated configuration: {filename}")
                        else:
                            print(f"Failed to update configuration: {filename}")
                            return False
                    finally:
                        os.unlink(temp_path)
            
            return True
            
        except Exception as e:
            print(f"Exception in healing action: {e}")
            return False
    
    def get_healing_summary(self) -> Dict:
        """Get summary of all healing attempts"""
        total_attempts = len(self.healing_log)
        successful_attempts = sum(1 for entry in self.healing_log if entry['success'])
        
        return {
            'total_attempts': total_attempts,
            'successful_attempts': successful_attempts,
            'success_rate': successful_attempts / total_attempts if total_attempts > 0 else 0,
            'actions_attempted': [entry['action'] for entry in self.healing_log],
            'log': self.healing_log
        }

# CLI interface for testing
def main():
    import sys
    
    if len(sys.argv) < 4:
        print("Usage: self-healing.py <vm_ip> <config_path> <error_pattern>")
        sys.exit(1)
    
    vm_ip = sys.argv[1]
    config_path = sys.argv[2]
    error_pattern = sys.argv[3]
    
    healer = SelfHealer(vm_ip, config_path)
    
    success = healer.attempt_healing(error_pattern)
    
    summary = healer.get_healing_summary()
    print(f"\nHealing Summary:")
    print(f"Success: {success}")
    print(f"Attempts: {summary['total_attempts']}")
    print(f"Success Rate: {summary['success_rate']:.1%}")
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()