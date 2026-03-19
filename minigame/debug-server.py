import http.server
import socketserver
import os
import argparse

# 1. 命令行参数处理
parser = argparse.ArgumentParser(description="WASM SourceMap 调试服务器")
parser.add_argument("--port", type=int, default=3000, help="监听端口 (默认: 3000)")
args = parser.parse_args()

# 2. 自动定位到项目根目录（minigame 的上一级）
# 这样服务器才能同时访问到 minigame/wasm 和 cpp-module/src
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(project_root)

class CORSRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # 允许跨域，否则微信开发者工具会拦截请求
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET')
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
        return super().end_headers()

    def log_message(self, format, *args):
        # 简单的日志格式化，方便查看加载请求
        print(f"[DEBUG SERVER] {self.address_string()} - {format%args}")

print(f"--------------------------------------------------")
print(f"WASM Debug Server 启动成功")
print(f"监听地址: http://127.0.0.1:{args.port}")
print(f"服务目录: {project_root}")
print(f"--------------------------------------------------")
print(f"等待微信开发者工具请求 SourceMap...")

try:
    with socketserver.TCPServer(("", args.port), CORSRequestHandler) as httpd:
        httpd.serve_forever()
except KeyboardInterrupt:
    print("\n服务器已停止")
except Exception as e:
    print(f"服务器启动失败: {e}")
