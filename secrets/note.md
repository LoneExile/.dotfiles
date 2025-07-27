
## 🔐 What is SOPS?

**SOPS** = **S**ecrets **OP**eration**S** - A tool that encrypts files (like passwords, API keys, certificates) so you can safely store them in git repositories.

## 📋 Breaking Down Your .sops.yaml File

### 🔑 The Keys Section
```yaml
keys:
  - &hosts:
    - &le: age17h7ugzlh8lzlxcl2rd2pv4h5v9qwwznu9vpzvyahmn5suv778cfq9v80ff
```

**What this does:**
- Defines **public keys** for one machines: `le`
- Uses **age encryption** (modern, simple encryption tool)
- `&le` are **YAML anchors** (like variables you can reuse)
- These are **public keys** - safe to store in git

### 🎯 The Creation Rules Section
```yaml
creation_rules:
  - path_regex: secrets/secrets.yaml$
    key_groups:
      - age:
        - *le
```

**What this does:**
- **Rule**: For any file matching `secrets/secrets.yaml`
- **Encrypt for**: `le` machine
- **Result**: Only this machine can decrypt the secret

## 🔄 How the Encryption Process Works

### 1. **Generate Age Keys** (Comments at top of file)
```bash
# Convert your SSH key to age format
nix run nixpkgs#ssh-to-age -- -private-key -i .ssh/id_ed25519 > ~/.config/sops/age/keys.txt

# Or generate new age keys
nix shell nixpkgs#age -c age-keygen -y ~/.config/sops/age/keys.txt
```

### 2. **Encrypt Secrets**
```bash
# Edit encrypted file (creates if doesn't exist)
nix run nixpkgs#sops -- secrets/secrets.yaml
```

### 3. **What Happens During Encryption:**
- SOPS reads your `.sops.yaml` config
- Encrypts the file with **both** public keys
- Either machine can decrypt it (if they have the private key)
- File becomes safe to commit to git

## 📁 Current Setup Analysis

Looking at your current setup:

### 🖥️ Your Machines:
- **le**: Appears to be one of your macOS machines

### 🔐 What's Encrypted:
Your `secrets/secrets.yaml` file contains (encrypted):
```yaml
# Example of what might be inside (when decrypted):
smb:
  username: myusername
  password: mysecretpassword
api_keys:
  github_token: ghp_xxxxxxxxxxxx
```

## 🚨 Important Security Notes

### ✅ Safe to Store in Git:
- `.sops.yaml` file (contains only public keys)
- `secrets/secrets.yaml` (encrypted, unreadable without private key)

### ❌ NEVER Store in Git:
- `~/.config/sops/age/keys.txt` (private keys)
- Decrypted versions of secret files

## 🔧 How to Use SOPS in Your macOS Setup

### **Add a New Secret:**
```bash
# Edit the encrypted file
nix run nixpkgs#sops -- secrets/secrets.yaml

# Add your secret in the editor that opens:
# new_api_key: "your-secret-value"
```

### **Add Your macOS Machine:**
1. **Generate age key for your Mac:**
   ```bash
   nix shell nixpkgs#age -c age-keygen > ~/.config/sops/age/keys.txt
   ```

2. **Get the public key:**
   ```bash
   # The public key is the part after "# public key: "
   cat ~/.config/sops/age/keys.txt
   ```

3. **Add to .sops.yaml:**
   ```yaml
   keys:
     - &hosts:
       - &le: age17h7ugzlh8lzlxcl2rd2pv4h5v9qwwznu9vpzvyahmn5suv778cfq9v80ff
       - &your-mac: age1your-new-public-key-here
   creation_rules:
     - path_regex: secrets/secrets.yaml$
       key_groups:
         - age:
           - *le
           - *your-mac
   ```

### **Re-encrypt for New Keys:**
```bash
# After adding your machine to .sops.yaml
nix run nixpkgs#sops -- updatekeys secrets/secrets.yaml
```

## 🎯 Why Use SOPS?

1. **Version Control**: Secrets are encrypted but trackable in git
2. **Multi-Machine**: Same secrets work across all your machines
3. **Secure**: Uses modern age encryption
4. **Integration**: Works seamlessly with nix-darwin and home-manager
5. **Audit Trail**: Changes to secrets are tracked in git history

## 💡 Real-World Example

```bash
# 1. Add WiFi password to secrets
nix run nixpkgs#sops -- secrets/secrets.yaml
# Add: wifi_password: "your-wifi-password"

# 2. Use in nix configuration
# In your darwin-common.nix:
sops.secrets.wifi_password = {};
# This makes the password available to your system securely
```

SOPS essentially lets you have a "encrypted vault" that travels with your nix-config, ensuring your sensitive data is both secure and available across all your machines!
