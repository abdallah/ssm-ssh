# Add to ~/.zshrc or to ~/.oh-my-zsh/custom/change-aws-profile.zsh
# https://github.com/rothgar/mastering-zsh/blob/master/docs/config/hooks.md
# precmd is executed before your prompt is displayed and is often used to set values in your $PROMPT. preexec is executed between when you press enter on a command prompt but before the command is executed

precmd() {
    if [[ $CURRENT_PROFILE != "$AWS_PROFILE" ]]; then
        echo changed, checking sts;
        export CURRENT_PROFILE=$AWS_PROFILE;
        if ! aws sts get-caller-identity; then
                aws sso login
        fi
    fi
}
