# NixOS Configuration Project Specification

## NixOS Configuration Engineering Architecture

### System Design Philosophy

**Architecture Pattern:** Declarative Infrastructure as Code with Flake-based Modular Composition  
**Core Paradigm:** Immutable system state derived from versioned configuration

#### Design Principles:
1. **Declarative Configuration**: Entire system state defined as code (disk→services)
2. **Modular Composition**: Discrete, reusable feature modules combined into profiles
3. **Layered Specialization**: Base foundation + role-specific profiles + optional features
4. **Abstraction & DRY**: Helper functions eliminate boilerplate, ensure consistency

### Architectural Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     flake.nix (Orchestrator)                 │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │   inputs    │  │  lib.mkSystem │  │     outputs      │   │
│  │ • nixpkgs   │  │   (factory)   │  │ • nixosConfigs   │   │
│  │ • disko     │  └──────┬───────┘  │ • apps           │   │
│  │ • home-mgr  │         │          │ • packages       │   │
│  └─────────────┘         ▼          └──────────────────┘   │
└───────────────────────────┴─────────────────────────────────┘
                            │
        ┌───────────────────┴───────────────────┐
        │          Module Composition           │
        │                                        │
        │  common.nix ─────► Always included    │
        │      +                                │
        │  base.nix ──────► Foundation layer    │
        │      +                                │
        │  profile.nix ───► Role specialization │
        │      +                                │
        │  modules/*.nix ─► Feature modules     │
        └────────────────────────────────────────┘
```

### Component Architecture

#### 1. **flake.nix** - Central Orchestrator
- **Role**: Entry point, dependency management, output definitions
- **Responsibilities**:
  - Define external dependencies (nixpkgs, disko, home-manager)
  - Map profile names → NixOS configurations via `lib.mkSystem`
  - Expose build artifacts (systems, apps, ISO images)
  - Provide development environment

#### 2. **lib/default.nix** - Abstraction Layer
- **Pattern**: Factory function for system generation
- **Key Function**: `mkSystem`
  ```nix
  mkSystem = { system, inputs, modules, username, hashedPassword }:
    → Prepends base.nix
    → Injects specialArgs globally
    → Returns nixosSystem configuration
  ```

#### 3. **Profile Hierarchy**
```
common.nix          [Universal: users, SSH, firewall settings]
    ↓
base.nix            [Foundation: boot, network, packages]
    ↓
┌─────────┴─────────┬──────────────┬─────────────┐
vm.nix           workstation.nix   server.nix    iso.nix
[minimal]        [desktop+dev]     [hardened]    [installer]
```

#### 4. **Module System**
- **Structure**: Self-contained feature sets with enable flags
- **Categories**:
  - Development environment
  - Gaming support
  - Media server stack
  - Security hardening
- **Activation**: `config.modules.<name>.enable = true`

#### 5. **Disk Layout** (disko-config.nix)
```
GPT Partition Table
├── EFI System Partition (1GB, FAT32)
└── BTRFS Root Partition (remaining)
    ├── @ (root subvolume)
    ├── @home
    ├── @nix
    ├── @log
    └── @snapshots
```

### Execution Flow & Control Sequencing

#### Build-Time Flow (Evaluation)
```
1. User invokes: nix build .#workstation
         ↓
2. Flake evaluation begins
   • Fetch inputs (nixpkgs, etc.)
   • Resolve requested output
         ↓
3. lib.mkSystem called
   • Prepend common.nix + base.nix
   • Add profile-specific modules
   • Inject specialArgs
         ↓
4. Module merge algorithm
   • Recursive attribute set merging
   • Priority resolution (mkForce)
   • Conditional inclusion (mkIf)
         ↓
5. Derivation generation
   • Package closures computed
   • System activation scripts built
   • Store paths realized
```

#### Installation Flow
```
1. install.sh script
   • Environment validation
   • Hardware detection
         ↓
2. Disk setup (disko)
   • Partition creation
   • BTRFS formatting
   • Subvolume creation
         ↓
3. NixOS installation
   • Generate hardware-configuration.nix
   • Copy system closure to /mnt
   • Install bootloader
         ↓
4. First boot
   • systemd-boot → kernel
   • Stage 1/2 init
   • Service activation
```

### Module Loading & Merge Semantics

#### Load Order:
1. `common.nix` - Universal settings (highest precedence)
2. `base.nix` - Foundation layer
3. Profile module (e.g., `workstation.nix`)
4. Imported feature modules
5. Hardware configuration (if present)

#### Merge Rules:
- Later definitions override earlier ones
- `lib.mkForce` bypasses normal precedence
- `lib.mkIf` provides conditional application
- `lib.mkMerge` explicitly combines values

### State Management Model

```
┌─────────────────┐     ┌──────────────────┐
│   Immutable     │     │    Mutable       │
├─────────────────┤     ├──────────────────┤
│ /nix/store      │     │ /home/*          │
│ /etc (managed)  │     │ /var/lib/*       │
│ /bin, /usr      │     │ /var/log/*       │
└─────────────────┘     └──────────────────┘
         ↑                        ↑
         │                        │
    Derived from             User/Service
    .nix files                  data
```

### Security & Performance Architecture

#### Security Model:
- **Network**: Firewall disabled (explicit choice)
- **Access**: SSH key-only root, passwordless sudo
- **Updates**: Declarative, atomic, rollback-capable

#### Performance Optimizations:
- **Memory**: ZRAM swap (50% compression ratio)
- **Storage**: BTRFS with zstd compression
- **I/O**: noatime mount options
- **Kernel**: Profile-specific (zen/hardened/lts)

### Extension & Customization Points

1. **New System Profiles**: Add to `nixosConfigurations` in flake.nix
2. **Feature Modules**: Create in `modules/` with standard interface
3. **Package Overrides**: Via overlays in profiles
4. **Service Extensions**: systemd units in modules
5. **User Configurations**: home-manager integration

### Key Architectural Benefits

- **Reproducibility**: Identical inputs → identical systems
- **Composability**: Mix and match features via modules
- **Maintainability**: Clear separation of concerns
- **Rollback Safety**: Previous generations preserved
- **Testing**: Build without deployment via `nix build`

This architecture achieves a balance between flexibility and standardization, allowing for both specialized system configurations and shared foundational elements while maintaining the ability to reproduce any system state deterministically.