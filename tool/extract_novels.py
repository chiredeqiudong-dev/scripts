import os
import sys
import re
import html
import json  # 引入 json 模块
import xml.etree.ElementTree as ET

# 1. 获取命令行参数
if len(sys.argv) > 1:
    folder_path = sys.argv[1]
else:
    print("用法: python extract_novels.py <文件夹路径> [输出JSON文件名]")
    sys.exit(1)

# 修改默认后缀名为 .json
output_json = sys.argv[2] if len(sys.argv) > 2 else 'novels_data.json'

# OPF 文件的标准命名空间
ns = {
    'opf': 'http://www.idpf.org/2007/opf',
    'dc': 'http://purl.org/dc/elements/1.1/'
}


# 2. 清洗函数
def clean_text(raw_html):
    if not raw_html:
        return ""
    clean_re = re.compile('<.*?>')
    text = re.sub(clean_re, '', raw_html)
    text = html.unescape(text).strip()
    return text


def parse_single_opf(file_path):
    try:
        tree = ET.parse(file_path)
        root = tree.getroot()
        metadata = root.find('opf:metadata', ns)
        if metadata is None:
            return None

        # 提取关键字段
        title_node = metadata.find('dc:title', ns)
        title = title_node.text if title_node is not None else "未知书名"

        creator_node = metadata.find('dc:creator', ns)
        author = creator_node.text if creator_node is not None else "未知作者"

        # 提取并清洗简介
        desc_node = metadata.find('dc:description', ns)
        raw_desc = desc_node.text if desc_node is not None else ""
        summary = clean_text(raw_desc)

        # 按照你之前的数据库结构预留字段，方便后续对接
        return {
            "title": title,
            "author": author,
            "category": "",
            "status": "",
            "rating": "",
            "reading_note": "",
            "summary": summary,
            "cover": ""
        }
    except Exception as e:
        print(f"解析失败 {file_path}: {e}")
        return None


# 3. 执行批量解析
all_novels = []
for root_dir, dirs, files in os.walk(folder_path):
    for file in files:
        if file.endswith('.opf'):
            full_path = os.path.join(root_dir, file)
            data = parse_single_opf(full_path)
            if data:
                all_novels.append(data)

# 4. 生成 JSON 文件
# ensure_ascii=False 保证中文不被转码为 \uXXXX，indent=4 让格式美观
with open(output_json, 'w', encoding='utf-8') as f:
    json.dump(all_novels, f, ensure_ascii=False, indent=4)

print(f"🎉 处理完成！共提取 {len(all_novels)} 本小说信息。")
print(f"💾 JSON 文件已保存至: {output_json}")