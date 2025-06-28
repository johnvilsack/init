{
    echo "# ========== PART 1: init.sh =========="
    cat ~/github/init/mac/setup/init.sh
    echo ""
    echo "# ========== PART 2: mac-install.sh =========="
    cat "$DOTFILESPATH/mac-install.sh"
} > ~/output.txt