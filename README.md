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
