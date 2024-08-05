from flask import Flask, request, jsonify, render_template
import sqlite3

app = Flask(__name__)

# Initialize SQLite database
def init_db():
    with sqlite3.connect('data.db') as conn:
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

@app.route('/')
def index():
    conn = sqlite3.connect('data.db')
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM data")
    rows = cursor.fetchall()
    conn.close()
    return render_template('index.html', rows=rows)

@app.route('/api/data', methods=['POST'])
def add_data():
    if not request.json:
        return jsonify({'error': 'Bad request'}), 400
    
    data = request.json
    fields = ('manufacturer', 'product', 'version', 'serial', 'pmn', 'ramtotal', 'hdl', 'hdserial', 'location', 'notes', 'atr')
    
    # Check if all fields are present
    if not all(field in data for field in fields):
        return jsonify({'error': 'Missing fields'}), 400
    
    with sqlite3.connect('data.db') as conn:
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO data (manufacturer, product, version, serial, pmn, ramtotal, hdl, hdserial, location, notes, atr)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (data['manufacturer'], data['product'], data['version'], data['serial'], data['pmn'], data['ramtotal'], data['hdl'], data['hdserial'], data['location'], data['notes'], data['atr']))
        conn.commit()
        data_id = cursor.lastrowid
    
    return jsonify({'id': data_id, 'data': data}), 201

@app.route('/api/data', methods=['GET'])
def get_data():
    conn = sqlite3.connect('data.db')
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM data")
    rows = cursor.fetchall()
    conn.close()
    
    data = [
        {
            'id': row[0],
            'manufacturer': row[1],
            'product': row[2],
            'version': row[3],
            'serial': row[4],
            'pmn': row[5],
            'ramtotal': row[6],
            'hdl': row[7],
            'hdserial': row[8],
            'location': row[9],
            'notes': row[10],
            'atr': row[11]
        }
        for row in rows
    ]
    
    return jsonify(data)

if __name__ == '__main__':
    init_db()
    app.run(debug=True)
