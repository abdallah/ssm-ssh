# ssm-ssh

**Collection of scripts to streamline SSH access over AWS SSM**

## Overview
This repository includes scripts that facilitate connecting to EC2 instances over SSH by leveraging AWS Systems Manager (SSM). It simplifies the process by providing predefined scripts to set up and manage SSH connections without needing a public IP or bastion host.

## Requirements

* AWS cli
* Session Manager (see [docs](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-enable-ssh-connections.html))
* OhMyZsh
* fzf

## Installation

```bash
# download the proxy command to your ssh directory (or anywhere ...)
wget https://raw.githubusercontent.com/abdallah/ssm-ssh/refs/heads/main/aws-ssm-ec2-proxy-command.sh -O ~/.ssh/aws-ssm-ec2-proxy-command.sh
chmod +x ~/.ssh/aws-ssm-ec2-proxy-command.sh

# download the custom zsh functions to ~/.ohmyzsh/custom/
wget https://raw.githubusercontent.com/abdallah/ssm-ssh/refs/heads/main/aws-ssh.zsh -O ~/.ohmyzsh/custom/aws-ssh.zsh
wget https://raw.githubusercontent.com/abdallah/ssm-ssh/refs/heads/main/change-aws-profile.zsh -O ~/.ohmyzsh/custom/change-aws-profile.zsh
```

## Usage

### for Install Proxy Command
- Move this script to ~/.ssh/aws-ssm-ec2-proxy-command.sh
- Ensure it is executable (chmod +x ~/.ssh/aws-ssm-ec2-proxy-command.sh)
- Add following SSH Config Entry to ~/.ssh/config
  ```
  host i-* mi-*
    IdentityFile ~/.ssh/id_rsa
    ProxyCommand ~/.ssh/aws-ssm-ec2-proxy-command.sh %h %r %p ~/.ssh/id_rsa.pub
    StrictHostKeyChecking no
  ```

- Ensure SSM Permissions for Target Instance Profile https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-instance-profile.html
- Open SSH Connection
  ```
  ssh <INSTANCE_USER>@<INSTANCE_ID>
  ```

... todo


## License
This project is licensed under the MIT License. 
