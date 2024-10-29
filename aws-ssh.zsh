# Add to ~/.zshrc or ~/.oh-my-zsh/custom/aws-ssh.zsh
# requires fzf and aws cli
assh() {
  ssh $(aws ec2 describe-instances \
    --filters Name=instance-state-name,Values=running \
    --query "Reservations[*].Instances[*].{Instance:InstanceId,Name:Tags[?Key=='Name']|[0].Value}" --output text | \
    fzf --prompt "Running instances" | awk '{print$1}')
}
