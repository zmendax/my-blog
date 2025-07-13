#!/bin/sh

# 下载 Hugo Extended 版本（Linux AMD64 示例，注意版本号换成你需要的）
wget https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_Linux-64bit.tar.gz

tar -xzf hugo_extended_${HUGO_VERSION}_Linux-64bit.tar.gz
chmod +x hugo

# 使用刚下载的 hugo 构建网站
./hugo --gc --minify
