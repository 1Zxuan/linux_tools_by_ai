#!/bin/bash

# 检查是否提供了参数
if [ -z "$1" ]; then
  echo "错误: 需要指定操作类型。"
  echo "用法: ./open_port.sh <操作类型>"
  echo "操作类型: show (查看已开放端口) 或 <端口号> (开放指定端口)"
  echo "或者使用 'help' 查看帮助信息"
  exit 1
fi

# 获取操作类型
OPERATION=$1

# 显示帮助信息
if [ "$OPERATION" == "help" ]; then
  echo "脚本帮助说明："
  echo
  echo "这个脚本用于管理系统防火墙的端口开放操作。"
  echo "用法: ./open_port.sh <操作类型>"
  echo
  echo "操作类型:"
  echo "  show    查看已开放的端口"
  echo "  <端口号> 开放指定的端口 (例如: ./open_port.sh 8080)"
  echo "  help    显示帮助信息"
  echo
  echo "该脚本支持以下防火墙工具："
  echo "  firewalld 适用于 CentOS、RHEL、Fedora、openSUSE"
  echo "  ufw       适用于 Ubuntu、Debian"
  echo
  exit 0
fi

# 检测操作系统类型
OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')

echo "检测到操作系统: $OS"

# 根据操作系统选择防火墙管理工具
FIREWALL_TOOL=""
if [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"RHEL"* ]] || [[ "$OS" == *"Fedora"* ]]; then
    FIREWALL_TOOL="firewalld"
elif [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    FIREWALL_TOOL="ufw"
elif [[ "$OS" == *"openSUSE"* ]]; then
    FIREWALL_TOOL="firewalld"
else
    echo "未支持的操作系统，脚本可能无法正常工作。"
    exit 1
fi

# 显示已开放端口的函数
show_ports() {
    if [ "$FIREWALL_TOOL" == "firewalld" ]; then
        firewall-cmd --zone=public --list-ports
    elif [ "$FIREWALL_TOOL" == "ufw" ]; then
        ufw status | grep 'ALLOW' | awk '{print $2}'
    else
        echo "未检测到已知的防火墙管理工具 (firewalld/ufw)。请手动检查端口。"
        exit 1
    fi
}

# 如果操作类型是 show，显示已开放的端口
if [ "$OPERATION" == "show" ]; then
  echo "显示已开放的端口："
  show_ports
  exit 0
fi

# 如果操作类型是端口号，执行开放端口的操作
if [[ "$OPERATION" =~ ^[0-9]+$ ]]; then
  PORT=$OPERATION
  echo "正在处理端口 $PORT ..."

  # 检查端口是否已经开放的函数
  check_open_port() {
      if [ "$FIREWALL_TOOL" == "firewalld" ]; then
          firewall-cmd --zone=public --list-ports | grep -qw "$PORT/tcp"
      elif [ "$FIREWALL_TOOL" == "ufw" ]; then
          ufw status | grep -qw "$PORT/tcp"
      else
          echo "未知防火墙工具，请手动检查端口 $PORT。"
          exit 1
      fi
  }

  # 检查端口是否已经开放
  if check_open_port; then
      echo "端口 $PORT 已经在防火墙中开放。"
      read -p "是否关闭端口 $PORT？输入 Y 关闭，N 忽略操作: " choice
      case "$choice" in
        Y|y)
            echo "正在关闭端口 $PORT ..."
            if [ "$FIREWALL_TOOL" == "firewalld" ]; then
                firewall-cmd --zone=public --remove-port=$PORT/tcp --permanent
                firewall-cmd --reload
            elif [ "$FIREWALL_TOOL" == "ufw" ]; then
                ufw deny $PORT/tcp
            fi
            echo "端口 $PORT 已成功关闭。"
            ;;
        N|n)
            echo "保持端口 $PORT 开放。"
            ;;
        *)
            echo "无效输入，跳过操作。"
            ;;
      esac
  else
      echo "端口 $PORT 未在防火墙中开放，正在开放端口 $PORT ..."
      if [ "$FIREWALL_TOOL" == "firewalld" ]; then
          firewall-cmd --zone=public --add-port=$PORT/tcp --permanent
          firewall-cmd --reload
      elif [ "$FIREWALL_TOOL" == "ufw" ]; then
          ufw allow $PORT/tcp
      fi
      echo "端口 $PORT 已成功开放。"
  fi
  exit 0
else
  # 如果输入的参数不是端口号或 "show"，则提示错误
  echo "错误: 参数无效。"
  echo "用法: ./open_port.sh <操作类型>"
  echo "操作类型: show (查看已开放端口) 或 <端口号> (开放指定端口)"
  echo "或者使用 'help' 查看帮助信息"
  exit 1
fi
