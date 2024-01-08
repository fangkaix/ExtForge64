#!/bin/sh

# 默认镜像文件大小为3072M
total_size_mb=3072

# 获取系统架构信息
arch=$(uname -m)

# 检查user_app文件夹是否存在
if [ ! -d "user_app" ]; then
    echo "user_app文件夹不存在,是否要创建? (Y/N): "
    read create_folder
    if [ "$create_folder" = "Y" ] || [ "$create_folder" = "y" ]; then
        mkdir user_app
        echo "user_app文件夹已创建,请将需要放入镜像文件的内容放入user_app文件夹后继续。"
    else
        echo "未创建user_app文件夹,无法生成镜像文件。"
        exit 1
    fi
fi

# 获取user_app文件夹大小（以KB为单位）
folder_size=$(du -s user_app | awk '{print $1}')

# 如果文件夹大小超过了total_size_mb,给出提示并退出
if [ "$folder_size" -gt $((total_size_mb * 1024)) ]; then
    echo "user_app文件夹大小超过了允许的大小 (${total_size_mb}MB)。请减小文件夹大小后重试。"
    exit 1
fi

# 如果文件夹为空,给出提示并询问是否继续
if [ "$folder_size" -eq 0 ]; then
    echo "user_app文件夹为空,是否继续生成镜像文件? (Y/N): "
    read continue_generate
    if [ "$continue_generate" != "Y" ] && [ "$continue_generate" != "y" ]; then
        echo "已取消生成镜像文件。"
        exit 0
    fi
fi

# 获取镜像文件保存路径
echo "请输入生成的img镜像的保存路径: "
read img_path

# 如果用户未输入路径或者输入的路径不合法,则使用当前路径
if [ -z "$img_path" ] || ! test -d "$(dirname "$img_path")"; then
    echo "输入的路径为空或不合法,将使用当前路径作为img镜像的保存路径。"
    img_path="./image.img"
elif echo "$img_path" | grep -q "/$"; then
    img_path="${img_path}image.img"
elif ! echo "$img_path" | grep -q "\.img$"; then
    img_path="${img_path}/image.img"
fi

# 检查最终的路径是否有效
if ! test -d "$(dirname "$img_path")"; then
    echo "输入的路径 $img_path 不可用,将使用默认路径 './image.img'"
    img_path="./image.img"
fi

# 获取该路径对应磁盘空间大小（以KB为单位）
disk_space=$(df -kP "$(dirname "$img_path")" | awk 'NR==2 {print $4}')

# 计算可用空间对应的镜像大小（MB）
available_space_mb=$((disk_space / 1024))

# 如果可用空间小于文件夹大小,则退出
if [ "$available_space_mb" -lt "$((folder_size / 1024))" ]; then
    echo "磁盘空间 (${available_space_mb}MB) 小于文件夹大小 (${folder_size / 1024}MB),无法生成镜像文件。"
    exit 1
fi

# 如果可用空间小于总大小,则选择剩余空间大小作为可用空间
if [ "$available_space_mb" -lt "$total_size_mb" ]; then
    echo "磁盘空间 (${available_space_mb}MB) 不足以容纳${total_size_mb}MB镜像文件,将使用剩余的磁盘空间。"
    total_size_mb=$available_space_mb
fi

# 打印make_ext4fs的路径供用户确认
echo "当前make_ext4fs的路径为: $arch/make_ext4fs"

# 给相应平台下的make_ext4fs文件添加执行权限
MAKE_EXT4FS_PATH=$arch/make_ext4fs
chmod +x "$MAKE_EXT4FS_PATH"

# 创建ext4格式的镜像文件
$MAKE_EXT4FS_PATH -s -l "${total_size_mb}M" "$img_path" user_app
