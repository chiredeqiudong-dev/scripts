#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import json
import argparse
import requests
from datetime import datetime
from typing import Dict, List, Optional

# Steam官方提供了Web API接口和文档 https://developer.valvesoftware.com/wiki/Steam_Web_API
# Token的申请页面：https://steamcommunity.com/dev/apikey
# 打开Steam客户端，点击右上角头像进入“账户明细”就可以查看到自己的Steam ID
# python fetch_steam_games.py --output games.json 将游戏数据保存到games.json文件中

# 配置Steam API
STEAM_API_KEY = os.getenv("STEAM_API_KEY", "")
STEAM_API_URL = "http://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/"
STEAM_ID = ""

class SteamGames:
    def __init__(self, api_key: str = STEAM_API_KEY):
        self.api_key = api_key
        self.headers = {"User-Agent": "Mozilla/5.0 (compatible)"}
    
    def fetch_owned_games(self, steam_id: str) -> Optional[Dict]:
        """获取用户的Steam游戏库数据"""
        params = {
            "key": self.api_key,
            "steamid": steam_id,
            "format": "json",
            "include_appinfo": 1,
            "include_played_free_games": 1
        }
        
        try:
            response = requests.get(STEAM_API_URL, params=params, headers=self.headers)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"错误: 获取游戏数据失败 - {str(e)}")
            return None

    def format_timestamp(self, timestamp: int) -> str:
        """将时间戳转换为可读格式"""
        if not timestamp:
            return ""
        return datetime.fromtimestamp(timestamp).strftime("%Y-%m-%d %H:%M:%S")
            
    def process_games_data(self, data: Dict) -> Dict:
        """处理游戏数据，只保留指定字段"""
        if not data or "response" not in data:
            return {"total": 0, "games": []}
            
        games = data["response"].get("games", [])
        processed_games = [{
            "name": game["name"],
            "playtime_forever": round(game["playtime_forever"] / 60, 1),  # 转换为小时
            "img_icon_url": f"https://media.steampowered.com/steamcommunity/public/images/apps/{game['appid']}/{game.get('img_icon_url', '')}.jpg" if game.get('img_icon_url') else "",
            "last_played": self.format_timestamp(game.get("rtime_last_played", 0)),
            "app_url": f"https://store.steampowered.com/app/{game['appid']}/"  # 添加商店页面URL
        } for game in games]
        
        # 按游戏时间排序
        processed_games.sort(key=lambda x: x["playtime_forever"], reverse=True)
        
        return {
            "total": len(processed_games),
            "games": processed_games
        }

def main():
    parser = argparse.ArgumentParser(description="获取Steam游戏库数据")
    parser.add_argument("--output", type=str, help="输出文件路径（JSON格式）")
    args = parser.parse_args()

    steam = SteamGames()
    
    print(f"正在获取Steam用户 {STEAM_ID} 的游戏数据...")
    data = steam.fetch_owned_games(STEAM_ID)
    
    if not data:
        print("获取数据失败")
        sys.exit(1)
        
    data = steam.process_games_data(data)
    # 按游戏时间排序
    data['games'].sort(key=lambda x: x["playtime_forever"], reverse=True)
    print(f"✓ 成功获取到 {data['total']} 个游戏")
    
    # 输出数据
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"✓ 数据已保存至: {args.output}")
        print(f"✓ 总计游戏数: {data['total']}")
    else:
        # 打印游戏信息
        print(f"\n游戏列表 (共{data['total']}个):")
        for game in data['games']:
            print(f"{game['name']:<40} - {game['playtime_forever']:>5}小时")
            if game["last_played"]:
                print(f"  最后游玩: {game['last_played']}")

if __name__ == "__main__":
    main()
