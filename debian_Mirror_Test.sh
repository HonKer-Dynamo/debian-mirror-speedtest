#!/bin/bash

# --- 颜色定义 ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;90m'
NC='\033[0m'

# ==================================================
# 1. 环境与系统检测
# ==================================================
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误: 请使用 sudo 运行此脚本 (例如: sudo ./test_mirror.sh)${NC}"
    exit 1
fi

if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "debian" && "$ID_LIKE" != *"debian"* ]]; then
        echo -e "${RED}错误: 此脚本仅适用于 Debian 及其衍生发行版。${NC}"
        exit 1
    fi
else
    echo -e "${RED}错误: 无法检测系统类型，仅支持 Debian 系列。${NC}"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo -e "${RED}错误: 未找到 curl 命令。请先执行: apt install curl${NC}"
    exit 1
fi

# ==================================================
# 2. 变量与智能配置
# ==================================================
CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2 | tr -d '\"')
if [ -z "$CODENAME" ]; then
    CODENAME="trixie"
fi

case $CODENAME in
    buster|stretch)
        COMPONENTS="main contrib non-free"
        SEC_SUFFIX="updates"
        UPDATES_SUFFIX="updates"
        ;;
    bullseye)
        COMPONENTS="main contrib non-free"
        SEC_SUFFIX="security"
        UPDATES_SUFFIX="updates"
        ;;
    bookworm|trixie|forky|sid)
        COMPONENTS="main contrib non-free non-free-firmware"
        SEC_SUFFIX="security"
        UPDATES_SUFFIX="updates"
        ;;
    *)
        COMPONENTS="main contrib non-free non-free-firmware"
        SEC_SUFFIX="security"
        UPDATES_SUFFIX="updates"
        ;;
esac
if [ "$CODENAME" = "sid" ] || [ "$CODENAME" = "forky" ]; then
    UPDATES_SUFFIX=""
fi

mirrors=(
    # 官方源说明：deb.debian.org 和 ftp.cn.debian.org 为官方调度入口，日常够用
    "deb.debian.org" "ftp.cn.debian.org" "debian-archive.trafficmanager.net"
    "mirrors.aliyun.com" "mirrors.cloud.tencent.com" "mirrors.huaweicloud.com"
    "mirrors.ctyun.cn" "mirrors.volces.com" "mirrors.163.com"
    "mirrors.tuna.tsinghua.edu.cn" "mirrors.pku.edu.cn" "mirrors.zju.edu.cn"
    "mirrors.ustc.edu.cn" "mirror.nju.edu.cn" "mirrors.sjtug.sjtu.edu.cn"
    "mirrors.hust.edu.cn" "mirror.lzu.edu.cn" "mirrors.bfsu.edu.cn"
    "mirrors.hit.edu.cn" "mirrors.neusoft.edu.cn" "mirror.nyist.edu.cn"
    "mirrors.jlu.edu.cn" "mirror.iscas.ac.cn" "mirrors.cstcloud.cn"
)

test_path="/debian/ls-lR.gz"
rounds=3
temp_file="/tmp/debian_mirror_test.tmp"
USER_AGENT="Debian APT-HTTP/1.3 (2.7.14)"

# ==================================================
# 3. 核心功能函数
# ==================================================

check_port() {
    local host=$1
    timeout 1 bash -c "cat < /dev/null > /dev/tcp/$host/443" 2>/dev/null
    return $?
}

format_speed() {
    local bytes=$1
    awk -v b="$bytes" 'BEGIN {
        if (b >= 1048576) printf "%.2f MB/s", b/1048576;
        else if (b >= 1024) printf "%.2f KB/s", b/1024;
        else printf "%.0f B/s", b;
    }'
}

test_with_apt() {
    local mirror=$1
    local tmp_list="/tmp/apt_test_sources.list"
    local tmp_lists_dir="/tmp/apt_test_lists"
    local tmp_cache_dir="/tmp/apt_test_cache"

    mkdir -p "$tmp_lists_dir/partial" "$tmp_cache_dir/archives/partial"

    cat > "$tmp_list" <<EOF
deb https://$mirror/debian/ $CODENAME $COMPONENTS
deb https://$mirror/debian-security/ $CODENAME-$SEC_SUFFIX $COMPONENTS
EOF

    apt-get update \
        -o Dir::Etc::sourcelist="$tmp_list" \
        -o Dir::Etc::sourceparts="-" \
        -o Dir::State::Lists="$tmp_lists_dir" \
        -o Dir::Cache="$tmp_cache_dir" \
        -o Acquire::Retries=0 \
        -o Acquire::http::Timeout=5 \
        -o Acquire::https::Timeout=5 > /dev/null 2>&1

    local exit_code=$?
    rm -rf "$tmp_list" "$tmp_lists_dir" "$tmp_cache_dir"
    return $exit_code
}

apply_mirror() {
    local mirror=$1
    echo -e "${YELLOW}准备将系统源更换为: https://$mirror/debian/${NC}"
    
    # 备份原配置 (仅保留最新一份)
    BACKUP_DIR="/etc/apt/backup"
    mkdir -p "$BACKUP_DIR"
    [ -f /etc/apt/sources.list ] && cp /etc/apt/sources.list "$BACKUP_DIR/sources.list.bak"
    [ -f /etc/apt/sources.list.d/debian.sources ] && cp /etc/apt/sources.list.d/debian.sources "$BACKUP_DIR/debian.sources.bak"
    echo -e "${GREEN}✔ 已将原配置备份至 $BACKUP_DIR${NC}"

    # 彻底清理可能冲突的新格式文件
    rm -f /etc/apt/sources.list.d/debian.sources
    rm -f /etc/apt/sources.list.d/*.bak.*

    # 强制写入经典的 sources.list 格式 (用户最熟悉)
    cat > /etc/apt/sources.list <<EOF
# 默认注释了源码镜像以提高 apt update 速度
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://$mirror/debian/ $CODENAME $COMPONENTS
# deb-src [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://$mirror/debian/ $CODENAME $COMPONENTS

deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://$mirror/debian-security/ $CODENAME-$SEC_SUFFIX $COMPONENTS
# deb-src [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://$mirror/debian-security/ $CODENAME-$SEC_SUFFIX $COMPONENTS
EOF
    if [ -n "$UPDATES_SUFFIX" ]; then
        cat >> /etc/apt/sources.list <<EOF

deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://$mirror/debian/ $CODENAME-$UPDATES_SUFFIX $COMPONENTS
# deb-src [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://$mirror/debian/ $CODENAME-$UPDATES_SUFFIX $COMPONENTS
EOF
    fi

    echo -e "${GREEN}✔ 软件源已成功更新！${NC}"
    
    if [[ "$mirror" == "ftp.cn.debian.org" || "$mirror" == "deb.debian.org" ]]; then
        echo -e "${CYAN}💡 提示: 您使用的是 Debian 官方调度源，它会自动重定向至国内最快的实体节点，日常使用完全足够。${NC}"
    fi

    echo -e "正在执行 apt update..."
    apt update
    echo ""
    read -p "按回车键返回主菜单..."
}

run_speed_test() {
    > "$temp_file"
    echo -e "${CYAN}开始极速探测并测速 (适配版本: $CODENAME)... ${NC}"
    
    for mirror in "${mirrors[@]}"; do
        printf "%-42s" "[测试] $mirror ..."
        
        if ! check_port "$mirror"; then
            echo -e "${GRAY}-> [跳过] 端口不通/宕机${NC}"
            continue
        fi

        inrelease_url="https://$mirror/debian/dists/$CODENAME/InRelease"
        http_code=$(curl -4 -L -k -A "$USER_AGENT" -o /dev/null -s -w "%{http_code}" -m 3 "$inrelease_url" 2>/dev/null)
        
        if [ "$http_code" != "200" ]; then
            if [ "$http_code" = "403" ]; then
                echo -e "${YELLOW}-> [跳过] 被防刷策略拦截 (403)${NC}"
            elif [ "$http_code" = "000" ]; then
                echo -e "${GRAY}-> [跳过] 连接超时 (000)${NC}"
            else
                echo -e "${GRAY}-> [跳过] 元数据无效 ($http_code)${NC}"
            fi
            continue
        fi

        url="https://$mirror$test_path"
        total_ms=0
        total_speed=0
        success=0
        
        for ((i=1; i<=rounds; i++)); do
            curl_out=$(curl -4 -L -k -A "$USER_AGENT" -o /dev/null -s -w "%{time_total} %{speed_download}" -m 3 "$url" 2>/dev/null)
            
            if [ -n "$curl_out" ]; then
                time_str=$(echo "$curl_out" | awk '{print $1}')
                speed_str=$(echo "$curl_out" | awk '{print $2}')
                is_valid=$(awk -v s="$speed_str" 'BEGIN {print (s > 10240) ? 1 : 0}')
                
                if [ "$is_valid" -eq 1 ]; then
                    ms=$(echo "$time_str" | awk '{printf "%d", $1 * 1000}')
                    total_ms=$((total_ms + ms))
                    total_speed=$(awk -v t="$total_speed" -v s="$speed_str" 'BEGIN {print t + s}')
                    success=$((success + 1))
                fi
            fi
        done
        
        if [ $success -gt 0 ]; then
            avg_ms=$((total_ms / success))
            avg_speed=$(awk -v t="$total_speed" -v c="$success" 'BEGIN {print t / c}')
            speed_formatted=$(format_speed "$avg_speed")
            
            echo -e "${GREEN}-> ${avg_ms} ms | ${speed_formatted}${NC}"
            echo "$avg_ms $mirror" >> "$temp_file"
        else
            echo -e "${RED}-> [测速失败/被拦截]${NC}"
        fi
    done
}

disable_cdrom() {
    echo -e "${CYAN}正在检查并禁用 DVD 本地源...${NC}"
    if grep -q "^deb cdrom:" /etc/apt/sources.list 2>/dev/null; then
        cp /etc/apt/sources.list /etc/apt/sources.list.bak
        sed -i 's/^deb cdrom:/# deb cdrom:/g' /etc/apt/sources.list
        echo -e "${GREEN}✔ 成功禁用 DVD 源。已备份原文件为 sources.list.bak${NC}"
    else
        echo -e "${YELLOW}提示: 未发现未注释的 DVD 源，可能已经禁用。${NC}"
    fi
    echo ""
    read -p "按回车键返回主菜单..."
}

view_current_sources() {
    clear
    echo -e "${CYAN}==================== [ 当前软件源配置 ] ====================${NC}"
    
    echo -e "${YELLOW}>>> 1. /etc/apt/sources.list <<<${NC}"
    if [ -s /etc/apt/sources.list ]; then
        cat /etc/apt/sources.list | grep -v "^#" | grep -v "^$"
        if [ $? -ne 0 ]; then echo -e "${GRAY}(只有注释或为空)${NC}"; fi
    else
        echo -e "${GRAY}(文件为空或不存在)${NC}"
    fi
    
    echo -e "\n${YELLOW}>>> 2. /etc/apt/sources.list.d/ 目录下的源文件 <<<${NC}"
    local has_files=false
    for file in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
        if [ -f "$file" ]; then
            has_files=true
            echo -e "${CYAN}[文件名: $(basename "$file")]${NC}"
            cat "$file" | grep -v "^#" | grep -v "^$"
            echo ""
        fi
    done
    if [ "$has_files" = false ]; then
        echo -e "${GRAY}(未发现其他源文件)${NC}"
    fi
    
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    read -p "按回车键返回主菜单..."
}

auto_configure() {
    run_speed_test
    
    if [ ! -s "$temp_file" ]; then
        echo -e "${RED}所有镜像测速均失败，无法继续。${NC}"
        read -p "按回车键返回..."
        return
    fi

    echo -e "\n${CYAN}==================== [ 测速结果排名 ] ====================${NC}"
    sort -n "$temp_file" | (
        rank=1
        while read -r latency mirror; do
            if [ $rank -eq 1 ]; then
                echo -e "${YELLOW}[最优选] ★ 延迟: ${latency} ms | 镜像: ${mirror}${NC}"
            else
                echo "[第 $rank 名]   延迟: ${latency} ms | 镜像: ${mirror}"
            fi
            rank=$((rank + 1))
        done
    )
    echo -e "${CYAN}========================================================${NC}\n"

    local FINAL_MIRROR=""
    local VALIDATE_PASSED=false

    while read -r latency mirror; do
        echo -e "${CYAN}正在使用真实 apt 引擎预检: ${YELLOW}$mirror${NC} ..."
        if test_with_apt "$mirror"; then
            echo -e "${GREEN}  ✔ 预检通过！apt 可以正常访问此源。${NC}"
            FINAL_MIRROR="$mirror"
            VALIDATE_PASSED=true
            break
        else
            echo -e "${RED}  ✖ 预检失败！(可能是 403 或证书错误)，降级测试下一个...${NC}"
        fi
    done < <(sort -n "$temp_file")

    if [ "$VALIDATE_PASSED" = false ]; then
        echo -e "${RED}错误: 所有候选镜像均未能通过 apt 真实预检！${NC}"
        read -p "按回车键返回..."
        return
    fi

    apply_mirror "$FINAL_MIRROR"
}

just_test() {
    run_speed_test
    echo -e "\n${CYAN}==================== [ 测速结果排名 ] ====================${NC}"
    if [ ! -s "$temp_file" ]; then
        echo -e "${RED}所有镜像测试均失败。${NC}"
    else
        sort -n "$temp_file" | (
            rank=1
            while read -r latency mirror; do
                if [ $rank -eq 1 ]; then
                    echo -e "${YELLOW}[最优选] ★ 延迟: ${latency} ms | 镜像: ${mirror}${NC}"
                else
                    echo "[第 $rank 名]   延迟: ${latency} ms | 镜像: ${mirror}"
                fi
                rank=$((rank + 1))
            done
        )
    fi
    echo -e "${CYAN}========================================================${NC}\n"
    read -p "按回车键返回主菜单..."
}

manual_configure() {
    clear
    echo -e "${CYAN}==================== [ 手动选择软件源 ] ====================${NC}"
    local i=1
    for m in "${mirrors[@]}"; do
        if [[ "$m" == "ftp.cn.debian.org" || "$m" == "deb.debian.org" ]]; then
            printf " %2d) %s %s(官方调度，日常够用)%s\n" "$i" "$m" "$GREEN" "$NC"
        else
            printf " %2d) %s\n" "$i" "$m"
        fi
        ((i++))
    done
    echo -e "${CYAN}========================================================${NC}"
    
    read -p "请输入要使用的源编号 (0 取消): " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#mirrors[@]}" ]; then
        local selected="${mirrors[$((choice-1))]}"
        echo ""
        if ! check_port "$selected"; then
            echo -e "${YELLOW}警告: 该源 TCP 443 端口不通，可能无法使用，但强制继续...${NC}"
        fi
        apply_mirror "$selected"
    elif [ "$choice" == "0" ]; then
        return
    else
        echo -e "${RED}无效的编号！${NC}"
        sleep 2
    fi
}

while true; do
    clear
    echo -e "${CYAN}========================================================${NC}"
    echo -e "${CYAN}         Debian 镜像源测速与配置工具 (全功能版)${NC}"
    echo -e "${CYAN}========================================================${NC}"
    echo " 1) 禁用本地 DVD/CDROM 源"
    echo " 2) 测速并自动设置最快的软件源 (推荐)"
    echo " 3) 仅测试镜像源速度 (不修改系统)"
    echo " 4) 手动选择并设置软件源"
    echo " 5) 查看当前软件源配置"
    echo " 0) 退出脚本"
    echo -e "${CYAN}========================================================${NC}"
    read -p "请输入选项 [0-5]: " choice

    case $choice in
        1) disable_cdrom ;;
        2) auto_configure ;;
        3) just_test ;;
        4) manual_configure ;;
        5) view_current_sources ;;
        0) echo "退出脚本。"; exit 0 ;;
        *) echo -e "${RED}无效选项，请重新输入。${NC}"; sleep 1 ;;
    esac
done