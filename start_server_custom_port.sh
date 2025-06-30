#\!/bin/bash

# 簡易カスタムポート起動スクリプト
PORT=${1:-3456}

echo "====================================="
echo "歯科クリニックシステム"
echo "ポート: $PORT で起動"
echo "====================================="

# 直接Railsを起動（vendor/bundleのRailsを使用）
if [ -f "vendor/bundle/ruby/3.3.0/bin/rails" ]; then
    echo "vendor bundleのRailsを使用..."
    vendor/bundle/ruby/3.3.0/bin/rails server -p $PORT
else
    echo "bin/railsを使用..."
    bin/rails server -p $PORT
fi
EOF < /dev/null
