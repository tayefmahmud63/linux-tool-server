from flask import Flask, request, jsonify, render_template, redirect, url_for, send_file
import sqlite3
import os
import pandas as pd

app = Flask(__name__)

def get_db(location):
    db_name = f'databases/{location}.db'
    if not os.path.exists(db_name):
        with sqlite3.connect(db_name) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS data (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    location TEXT,
                    atr TEXT,
                    note TEXT,
                    ram_total_gb TEXT,
                    processor TEXT,
                    hard_disk_size_gb TEXT,
                    laptop_brand TEXT,
                    model_number TEXT,
                    serial_number TEXT,
                    hard_disk_serial_number TEXT,
                    asset_type TEXT  -- New field
                )
            ''')
            conn.commit()
    return sqlite3.connect(db_name)


@app.route('/', methods=['GET'])
def home():
    databases = [f.replace('.db', '') for f in os.listdir('databases') if f.endswith('.db')]
    entries_count = {}
    for db in databases:
        conn = get_db(db)
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM data")
        count = cursor.fetchone()[0]
        entries_count[db] = count
        conn.close()
    return render_template('home.html', databases=databases, entries_count=entries_count)

@app.route('/<location>', methods=['GET'])
def index(location):
    conn = get_db(location)
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM data")
    rows = cursor.fetchall()
    conn.close()
    return render_template('index.html', rows=rows, location=location)

@app.route('/delete/<location>', methods=['POST'])
def delete_database(location):
    db_name = f'databases/{location}.db'
    if os.path.exists(db_name):
        os.remove(db_name)
    return redirect(url_for('home'))

@app.route('/delete/<location>/<int:row_id>', methods=['POST'])
def delete_row(location, row_id):
    conn = get_db(location)
    cursor = conn.cursor()
    cursor.execute("DELETE FROM data WHERE id=?", (row_id,))
    conn.commit()
    conn.close()
    return redirect(url_for('index', location=location))

@app.route('/export/<location>', methods=['GET'])
def export_data(location):
    db_name = f'databases/{location}.db'
    conn = sqlite3.connect(db_name)
    query = "SELECT * FROM data"
    df = pd.read_sql_query(query, conn)
    conn.close()

    excel_file = f'{location}.xlsx'
    df.to_excel(excel_file, index=False)

    return send_file(excel_file, as_attachment=True)

@app.route('/api/data', methods=['POST'])
def add_data():
    if not request.json or 'location' not in request.json:
        return jsonify({'error': 'Bad request'}), 400
    
    data = request.json
    location = data['location']
    
    fields = ('location', 'atr', 'note', 'ram_total_gb', 'processor', 'hard_disk_size_gb', 'laptop_brand', 'model_number', 'serial_number', 'hard_disk_serial_number', 'asset_type')
    
    if not all(field in data for field in fields):
        return jsonify({'error': 'Missing fields'}), 400
    
    conn = get_db(location)
    cursor = conn.cursor()
    cursor.execute('''
        INSERT INTO data (location, atr, note, ram_total_gb, processor, hard_disk_size_gb, laptop_brand, model_number, serial_number, hard_disk_serial_number, asset_type)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', (data['location'], data['atr'], data['note'], data['ram_total_gb'], data['processor'], data['hard_disk_size_gb'], data['laptop_brand'], data['model_number'], data['serial_number'], data['hard_disk_serial_number'], data['asset_type']))
    conn.commit()
    data_id = cursor.lastrowid
    conn.close()
    
    return jsonify({'id': data_id, 'data': data}), 201


if __name__ == '__main__':
    if not os.path.exists('databases'):
        os.makedirs('databases')
    app.run(debug=True, host="0.0.0.0")
