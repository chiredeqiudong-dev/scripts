import pandas as pd
import argparse
import os
import json

def convert_excel_to_json(input_path, output_path=None):
    if not os.path.exists(input_path):
        print(f"❌ 错误: 找不到文件 '{input_path}'")
        return

    try:
        df = pd.read_excel(input_path)

        if not output_path:
            base_name = os.path.splitext(input_path)[0]
            output_path = f"{base_name}.json"

        # 【修改这里】先转成字典，再用 json 库写入
        records = df.to_dict(orient='records')
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(records, f, ensure_ascii=False, indent=4)
        
        print(f"✅ 转换成功: {input_path}  ->  {output_path}")

    except Exception as e:
        print(f"❌ 转换过程中发生错误: {e}")

# ... (下方的 argparse 命令行代码保持不变) ...

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="将 Excel 文件转换为 JSON 格式")
    parser.add_argument("input", help="输入的 Excel 文件路径 (.xlsx 或 .xls)")
    parser.add_argument("-o", "--output", help="输出的 JSON 文件路径 (可选)", default=None)

    args = parser.parse_args()
    
    convert_excel_to_json(args.input, args.output)