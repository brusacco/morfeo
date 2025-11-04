#!/bin/bash
# Auto-fix all trailing whitespace and formatting issues

echo "🔧 Auto-formatting Ruby files..."
echo

# Fix all Ruby files
echo "Fixing *.rb files..."
bundle exec rubocop app/ lib/ config/ --only Layout/TrailingWhitespace --autocorrect --format simple

# Fix rake tasks
echo
echo "Fixing rake tasks..."
bundle exec rubocop lib/tasks/ --only Layout/TrailingWhitespace --autocorrect --format simple

# Fix all Layout issues
echo
echo "Fixing all layout issues..."
bundle exec rubocop app/ lib/ --only Layout --autocorrect --format simple

echo
echo "✅ Done! All trailing whitespace removed."
echo
echo "💡 Tip: Install the EditorConfig plugin in your editor to auto-trim on save"
echo "   VSCode/Cursor: Install 'EditorConfig for VS Code' extension"

