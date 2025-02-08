#!/bin/bash

# ------------------------------------------------------------------------------
# 版权声明：
#
# 文件名: cert_convert.sh
# 版本: 1.0
# 作者: 3kk0
# 创建日期: 2025-02-08
# 最后修改日期: 2025-02-08
# 版权: © 3kk0, 2025. 保留所有权利
#
# 根据 MIT 许可证授权。详情见 LICENSE 文件。
#
# 免责声明：
# 本脚本仅供参考。作者对使用本脚本所造成的任何后果不承担任何责任。
# 请根据您的环境和需求修改并测试脚本，确保其适用性和安全性。
# ------------------------------------------------------------------------------
# 描述：
# 本脚本自动化将 PEM 格式证书转换为 PKCS #12 格式的过程。
# 它会检查证书是否有更新，进行转换，并更新证书的哈希值，以便进行未来的比较。
#
# 该脚本适用于 Let's Encrypt 证书，但可以根据需要修改以适配其他证书。
# ------------------------------------------------------------------------------

# 常量部分
CERT_DIR="/path/to/your/certificate/directory"  # Let's Encrypt 证书目录路径
DOMAIN="yourdomain.com"  # 域名
PFX_FILE="${CERT_DIR}/${DOMAIN}.pfx"  # 输出的 .pfx 文件路径
CERTHASH_FILE="${CERT_DIR}/carthash"  # 存储 cert.pem 哈希值的文件

# 输入文件
CERT_FILE="${CERT_DIR}/cert.pem"  # 证书文件路径
CHAIN_FILE="${CERT_DIR}/chain.pem"  # 证书链文件路径
KEY_FILE="${CERT_DIR}/privkey.pem"  # 私钥文件路径

# PFX 密码
PFX_PASSWORD="your_pfx_password"  # 请替换为实际的 PFX 密码

# 日志文件路径
LOG_FILE="${CERT_DIR}/convert.log"  # 日志文件路径

# 用于捕获 openssl 输出的临时文件
TEMP_FILE=$(mktemp)

# 执行证书转换的函数
convert_cert() {
    # 执行转换命令
    if openssl pkcs12 -export -out "$PFX_FILE" -inkey "$KEY_FILE" -in "$CERT_FILE" -certfile "$CHAIN_FILE" -password pass:"$PFX_PASSWORD" > "$TEMP_FILE" 2>&1; then
        # 转换成功
        CERT_VALIDITY=$(date -d "$(openssl x509 -enddate -noout -in "$CERT_FILE" | sed 's/^.*=//')" +"%Y-%m-%d")

        # 记录成功并显示证书到期时间
        echo "[$(date)] 证书转换成功，证书到期时间：$CERT_VALIDITY" >> "$LOG_FILE"

        # 更新 cert.pem 的哈希值
        echo "$CURRENT_HASH" > "$CERTHASH_FILE"
    else
        # 转换失败，记录错误信息
        ERROR_MSG=$(cat "$TEMP_FILE")
        echo "[$(date)] 证书转换失败，错误信息：$ERROR_MSG" >> "$LOG_FILE"
    fi
}

# 检查 carthash 文件是否存在
if [ ! -f "$CERTHASH_FILE" ]; then
    echo "[$(date)] 开始创建新的 PKCS #12 证书。" >> "$LOG_FILE"

    # 执行证书转换
    convert_cert
    # 保存 cert.pem 的哈希值
    openssl x509 -noout -fingerprint -sha256 -in "$CERT_FILE" | sed 's/^.*=//' > "$CERTHASH_FILE"
else
    # carthash 文件存在，检查哈希值是否不同
    CURRENT_HASH=$(openssl x509 -noout -fingerprint -sha256 -in "$CERT_FILE" | sed 's/^.*=//')
    STORED_HASH=$(cat "$CERTHASH_FILE")

    if [ "$CURRENT_HASH" != "$STORED_HASH" ]; then
        echo "[$(date)] 原证书已更新，正在同步更新 PKCS #12 证书。" >> "$LOG_FILE"

        # 执行证书转换
        convert_cert

        # 更新 cert.pem 的哈希值
        echo "$CURRENT_HASH" > "$CERTHASH_FILE"
    fi
fi

# 删除临时文件
rm -f "$TEMP_FILE"
