#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LRC 文件编码转换脚本
将指定文件夹（包括子文件夹）中的所有 .lrc 文件转换为 ANSI 编码
原文件保留不变，转换后的文件以 _ansi.lrc 后缀保存
"""

import os
import sys
import chardet
from pathlib import Path


def detect_encoding(file_path, default='utf-8'):
    """
    检测文件的编码方式
    """
    try:
        with open(file_path, 'rb') as f:
            raw_data = f.read(10000)  # 读取前10000字节用于检测
            result = chardet.detect(raw_data)
            encoding = result.get('encoding', default)
            return encoding if encoding else default
    except Exception as e:
        print(f"  ⚠ 检测编码失败 {file_path}: {e}，使用默认编码 {default}")
        return default


def convert_lrc_to_ansi(source_file, output_file=None):
    """
    将 LRC 文件转换为 ANSI 编码
    
    :param source_file: 源文件路径
    :param output_file: 输出文件路径（如果为 None，则使用 _ansi 后缀）
    :return: 是否转换成功
    """
    try:
        # 确定输出文件路径
        if output_file is None:
            base_path = str(source_file)
            output_file = base_path.replace('.lrc', '_ansi.lrc')
        
        # 检测源文件编码
        source_encoding = detect_encoding(source_file)
        
        # 读取源文件
        with open(source_file, 'r', encoding=source_encoding, errors='replace') as f:
            content = f.read()
        
        # 保存为 ANSI 编码（cp936 是 Windows 中文 ANSI）
        with open(output_file, 'w', encoding='cp936', errors='replace') as f:
            f.write(content)
        
        print(f"✓ {source_file}")
        print(f"  源编码: {source_encoding} → 输出编码: cp936 (ANSI GBK)")
        print(f"  输出: {output_file}")
        return True
    
    except Exception as e:
        print(f"✗ 转换失败 {source_file}: {e}")
        return False


def process_folder(root_path, replace_original=False):
    """
    递归处理文件夹中的所有 .lrc 文件
    
    :param root_path: 根文件夹路径
    :param replace_original: 是否替换原文件（默认 False，创建新文件）
    """
    root_path = Path(root_path)
    
    if not root_path.exists():
        print(f"错误: 文件夹不存在 {root_path}")
        return
    
    if not root_path.is_dir():
        print(f"错误: 不是文件夹 {root_path}")
        return
    
    # 查找所有 .lrc 文件
    lrc_files = list(root_path.rglob('*.lrc'))
    
    if not lrc_files:
        print(f"未找到 .lrc 文件在 {root_path}")
        return
    
    print(f"找到 {len(lrc_files)} 个 .lrc 文件")
    print("=" * 70)
    
    success_count = 0
    
    for lrc_file in sorted(lrc_files):
        if replace_original:
            # 直接替换原文件
            temp_file = str(lrc_file) + '.tmp'
            success = convert_lrc_to_ansi(lrc_file, temp_file)
            if success:
                os.replace(temp_file, lrc_file)
                success_count += 1
        else:
            # 创建新文件
            success = convert_lrc_to_ansi(lrc_file)
            if success:
                success_count += 1
        print()
    
    print("=" * 70)
    print(f"完成: {success_count}/{len(lrc_files)} 个文件转换成功")

def main():
    if len(sys.argv) < 2:
        print("使用方法:")
        print("  python convert_lrc_to_ansi.py <root_folder> [--replace]")
        print()
        print("参数:")
        print("  <root_folder>  要处理的根文件夹路径")
        print("  --replace      替换原文件（默认创建 _ansi.lrc 新文件）")
        print()
        print("示例:")
        print("  python convert_lrc_to_ansi.py D:/Music")
        print("  python convert_lrc_to_ansi.py D:/Music --replace")
        sys.exit(1)
    
    root_folder = sys.argv[1]
    replace_original = '--replace' in sys.argv
    
    if replace_original:
        confirm = input(f"即将替换 {root_folder} 中的所有 .lrc 文件，是否继续? (y/n): ")
        if confirm.lower() != 'y':
            print("已取消")
            return
    
    process_folder(root_folder, replace_original=replace_original)


if __name__ == '__main__':
    main()
