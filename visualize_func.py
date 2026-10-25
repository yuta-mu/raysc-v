import csv

functions = []
counts = []
with open("function_execution_summary.csv", "r") as f:
    reader = csv.DictReader(f)
    for row in reader:
        functions.append(row["Function_Name"])
        counts.append(int(row["Execution_Count"]))

# グラフには上位10個を表示する
top_funcs = functions[:10]
top_counts = counts[:10]

html_content = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Raytracer Function Hotspot Analysis</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body {{ font-family: sans-serif; margin: 40px; background: #f4f4f9; color: #333; }}
        .container {{ max-width: 900px; margin: auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }}
        h1 {{ color: #2c3e50; }}
        table {{ width: 100%; border-collapse: collapse; margin-top: 20px; }}
        th, td {{ padding: 12px; border: 1px solid #ddd; text-align: left; }}
        th {{ background-color: #27ae60; color: white; }}
        tr:nth-child(even) {{ background-color: #f9f9f9; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>Raytracer 関数別 実行ホットスポット解析</h1>
        <p>QEMUの実行ログから抽出した、RISC-Vレイトレーサーの関数別実行回数ランキングです。</p>
        
        <div style="width: 100%; max-width: 800px; margin: 30px auto;">
            <canvas id="funcChart"></canvas>
        </div>

        <h2>全関数 実行回数一覧</h2>
        <table>
            <tr><th>関数名</th><th>実行回数</th></tr>
"""

for func, count in zip(functions, counts):
    html_content += f"            <tr><td>{func}</td><td>{count:,}</td></tr>\n"

html_content += f"""
        </table>
    </div>
    <script>
        const ctx = document.getElementById('funcChart').getContext('2d');
        const chart = new Chart(ctx, {{
            type: 'bar',
            data: {{
                labels: {top_funcs},
                datasets: [{{
                    label: '実行回数 (回)',
                    data: {top_counts},
                    backgroundColor: 'rgba(39, 174, 96, 0.6)',
                    borderColor: 'rgba(39, 174, 96, 1)',
                    borderWidth: 1
                }}]
            }},
            options: {{
                responsive: true,
                scales: {{
                    y: {{ beginAtZero: true }}
                }}
            }}
        }});
    </script>
</body>
</html>
"""

with open("function_report.html", "w") as f:
    f.write(html_content)

print("完了！ 'function_report.html' が生成されました。")
