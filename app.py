from flask import Flask, request, jsonify
import sqlite3
import os

app = Flask(__name__)

def get_db(location):
    db_name = f'{location}.db'
    if not os.path.exists(db_name):
        with sqlite3.connect(db_name) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS data (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    manufacturer TEXT,
                    product TEXT,
                    version TEXT,
                    serial TEXT,
                    pmn TEXT,
                    ramtotal TEXT,
                    hdl TEXT,
                    hdserial TEXT,
                    location TEXT,
                    notes TEXT,
                    atr TEXT
                )
            ''')
            conn.commit()
    return sqlite3.connect(db_name)

@app.route('/<location>', methods=['GET'])
def index(location):
    conn = get_db(location)
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM data")
    rows = cursor.fetchall()
    conn.close()
    
    # Generate HTML with enhanced styling
    html = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Hardware Report : {location}</title>
        <style>
            body {{
                font-family: Arial, sans-serif;
                margin: 0;
                padding: 0;
                background-color: #f4f4f4;
            }}
            header {{
                background-color: #4CAF50;
                color: white;
                padding: 10px 0;
                text-align: center;
            }}
            h1 {{
                margin: 0;
            }}
            table {{
                width: 80%;
                margin: 20px auto;
                border-collapse: collapse;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                background-color: white;
            }}
            table th, table td {{
                border: 1px solid #ddd;
                padding: 8px;
                text-align: center;
            }}
            table th {{
                background-color: #4CAF50;
                color: white;
            }}
            table tr:nth-child(even) {{
                background-color: #f2f2f2;
            }}
            table tr:hover {{
                background-color: #ddd;
            }}
            footer {{
                background-color: #4CAF50;
                color: white;
                text-align: center;
                padding: 10px 0;
                position: fixed;
                width: 100%;
                bottom: 0;
            }}
        </style>
    </head>
    <body>
        <header>
            <h1>Hardware Report :  {location}</h1>
            
        </header>
        <table>
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Manufacturer</th>
                    <th>Product</th>
                    <th>Version</th>
                    <th>Serial</th>
                    <th>Processor</th>
                    <th>RAM Total</th>
                    <th>HDD Size</th>
                    <th>HD Serial</th>
                    <th>Location</th>
                    <th>Notes</th>
                    <th>ATR</th>
                </tr>
            </thead>
            <tbody>
    """
    for row in rows:
        html += f"""
            <tr>
                <td>{row[0]}</td>
                <td>{row[1]}</td>
                <td>{row[2]}</td>
                <td>{row[3]}</td>
                <td>{row[4]}</td>
                <td>{row[5]}</td>
                <td>{row[6]}</td>
                <td>{row[7]}</td>
                <td>{row[8]}</td>
                <td>{row[9]}</td>
                <td>{row[10]}</td>
                <td>{row[11]}</td>
            </tr>
        """
    html += """
            </tbody>
        </table>
        <footer>
            <p>&copy; 2024 My Flask Application</p>
        </footer>
    </body>
    </html>
    """
    return html

@app.route('/api/data', methods=['POST'])
def add_data():
    if not request.json or 'location' not in request.json:
        return jsonify({'error': 'Bad request'}), 400
    
    data = request.json
    location = data['location']
    
    fields = ('manufacturer', 'product', 'version', 'serial', 'pmn', 'ramtotal', 'hdl', 'hdserial', 'location', 'notes', 'atr')
    
    if not all(field in data for field in fields):
        return jsonify({'error': 'Missing fields'}), 400
    
    conn = get_db(location)
    cursor = conn.cursor()
    cursor.execute('''
        INSERT INTO data (manufacturer, product, version, serial, pmn, ramtotal, hdl, hdserial, location, notes, atr)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', (data['manufacturer'], data['product'], data['version'], data['serial'], data['pmn'], data['ramtotal'], data['hdl'], data['hdserial'], data['location'], data['notes'], data['atr']))
    conn.commit()
    data_id = cursor.lastrowid
    conn.close()
    
    return jsonify({'id': data_id, 'data': data}), 201

if __name__ == '__main__':
    app.run(debug=True,host="0.0.0.0")
