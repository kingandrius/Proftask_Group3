from flask import Flask, request, jsonify, render_template_string
import os
import socket
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime

app = Flask(__name__)

AUTH_MODE = os.getenv("AUTH_MODE", "legacy")  # 'legacy' in EduCloud, 'entra' in Azure
LEGACY_STAFF_PASSWORD = os.getenv("LEGACY_STAFF_PASSWORD", "fonteynstaff2026")
ARRIVALS_API_KEY = os.getenv("ARRIVALS_API_KEY", "")  # empty = open in legacy mode
ENV_LABEL = os.getenv("ENV_LABEL", "Legacy DMZ (Single Server - EduCloud)")


def get_db_connection():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "db"),
        port=os.getenv("DB_PORT", "5432"),
        database=os.getenv("DB_NAME", "fonteyn_bookings"),
        user=os.getenv("DB_USER", "fonteyn_user"),
        password=os.getenv("DB_PASSWORD", "ChangeMeLocalLab2026"),
        sslmode=os.getenv("DB_SSLMODE", "prefer"),
    )


MAIN_TEMPLATE = """<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Fonteyn Holiday Parks – Booking Portal</title>
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; margin: 32px; background: #f1f5f9; color: #0f172a; }
    .container { max-width: 920px; margin: 0 auto; background: #fff; padding: 28px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,.08); }
    .topbar { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #2563eb; padding-bottom: 12px; margin-bottom: 20px; }
    h1 { margin: 0; font-size: 22px; color: #1e3a8a; }
    .env-pill { font-size: 12px; background: #eff6ff; color: #1d4ed8; padding: 5px 10px; border-radius: 999px; font-weight: 600; }
    .alert { padding: 11px 14px; background: #dcfce7; color: #166534; border-left: 4px solid #22c55e; margin-bottom: 16px; border-radius: 4px; }
    .error { padding: 11px 14px; background: #fee2e2; color: #991b1b; border-left: 4px solid #ef4444; margin-bottom: 16px; border-radius: 4px; }
    form { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; background: #f8fafc; padding: 18px; border-radius: 6px; border: 1px solid #e2e8f0; margin-bottom: 24px; }
    .full { grid-column: span 2; text-align: right; }
    label { display: block; font-size: 13px; font-weight: 600; margin-bottom: 4px; }
    input, select { width: 100%; padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; box-sizing: border-box; }
    button { background: #2563eb; color: #fff; border: none; padding: 9px 16px; border-radius: 4px; font-weight: 600; cursor: pointer; }
    button:hover { background: #1d4ed8; }
    table { width: 100%; border-collapse: collapse; font-size: 14px; }
    th, td { border-bottom: 1px solid #e2e8f0; padding: 9px 10px; text-align: left; }
    th { background: #f8fafc; color: #334155; font-weight: 600; }
    .badge { padding: 2px 8px; border-radius: 12px; font-size: 12px; font-weight: 600; background: #e2e8f0; }
    .Arriving { background: #fef3c7; color: #92400e; }
    .Checked { background: #dbeafe; color: #1e40af; }
    .Confirmed { background: #dcfce7; color: #166534; }
    .footer { margin-top: 20px; font-size: 12px; color: #64748b; display: flex; justify-content: space-between; }
  </style>
</head>
<body>
  <div class="container">
    <div class="topbar">
      <h1>Fonteyn Holiday Parks – Bookings</h1>
      <span class="env-pill">{{ env_label }} · Host: {{ hostname }}</span>
    </div>

    {% if message %}<div class="alert">{{ message }}</div>{% endif %}
    {% if error %}<div class="error">{{ error }}</div>{% endif %}

    <form method="POST" action="/">
      <div><label>Guest Name</label><input type="text" name="guest_name" required placeholder="e.g. Marie Janssen"></div>
      <div><label>Email</label><input type="email" name="email" required placeholder="marie@example.nl"></div>
      <div><label>Park</label>
        <select name="park_code">
          <option value="NL-HEL">NL-HEL (Helmond)</option>
          <option value="BE-01">BE-01 (Belgium)</option>
          <option value="DE-01">DE-01 (Germany)</option>
        </select>
      </div>
      <div><label>Cabin</label><input type="text" name="cabin_number" required placeholder="e.g. C14"></div>
      <div><label>Arrival Date</label><input type="date" name="arrival_date" required></div>
      <div><label>Departure Date</label><input type="date" name="departure_date" required></div>
      <div class="full"><button type="submit">Book Stay</button></div>
    </form>

    <table>
      <thead>
        <tr><th>ID</th><th>Guest</th><th>Park</th><th>Cabin</th><th>Dates</th><th>Status</th></tr>
      </thead>
      <tbody>
        {% for b in bookings %}
        <tr>
          <td>#{{ b.id }}</td>
          <td>{{ b.guest_name }}<br><small style="color:#64748b">{{ b.email }}</small></td>
          <td>{{ b.park_code }}</td>
          <td><strong>{{ b.cabin_number }}</strong></td>
          <td>{{ b.arrival_date }} → {{ b.departure_date }}</td>
          <td><span class="badge {{ b.status.split()[0] }}">{{ b.status }}</span></td>
        </tr>
        {% endfor %}
      </tbody>
    </table>

    <div class="footer">
      <span><a href="/staff">Staff Portal</a> · <a href="/api/arrivals">Arrivals API (JSON)</a> · <a href="/health">Health</a></span>
      <span>Total shown: {{ bookings|length }}</span>
    </div>
  </div>
</body>
</html>"""

STAFF_TEMPLATE = """<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Fonteyn Staff Portal</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 48px; background: #e2e8f0; }
    .card { max-width: 480px; margin: 0 auto; background: #fff; padding: 28px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,.1); }
    h1 { margin-top: 0; font-size: 20px; color: #1e3a8a; }
    input { width: 100%; padding: 8px; margin: 6px 0 14px; box-sizing: border-box; }
    button { width: 100%; padding: 10px; background: #dc2626; color: #fff; border: none; border-radius: 4px; font-weight: 600; cursor: pointer; }
    .ok { background: #dcfce7; color: #166534; padding: 12px; border-radius: 4px; margin-bottom: 14px; }
    .err { background: #fee2e2; color: #991b1b; padding: 10px; border-radius: 4px; margin-bottom: 14px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Fonteyn Staff Back-End ({{ auth_mode|upper }})</h1>
    {% if error %}<div class="err">{{ error }}</div>{% endif %}
    {% if authorized %}
      <div class="ok">Signed in as <strong>{{ staff_user }}</strong></div>
      <p>Active bookings in database: <strong>{{ count }}</strong></p>
      <p><a href="/">← Back to guest portal</a></p>
    {% else %}
      <form method="POST">
        <p style="font-size:13px;color:#475569;">Legacy shared admin login (replaced by Entra ID SSO + MFA in Azure).</p>
        <label>Username</label><input type="text" name="username" value="admin" readonly>
        <label>Shared Password</label><input type="password" name="password" required>
        <button type="submit">Sign In</button>
      </form>
    {% endif %}
  </div>
</body>
</html>"""


@app.route("/", methods=["GET", "POST"])
def index():
    message = None
    error = None

    if request.method == "POST":
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute(
                """INSERT INTO bookings (guest_name, email, park_code, arrival_date, departure_date, cabin_number, status)
                   VALUES (%s, %s, %s, %s, %s, %s, %s)""",
                (
                    request.form["guest_name"],
                    request.form["email"],
                    request.form.get("park_code", "NL-HEL"),
                    request.form["arrival_date"],
                    request.form["departure_date"],
                    request.form["cabin_number"],
                    "Confirmed",
                ),
            )
            conn.commit()
            cur.close()
            conn.close()
            message = f"Booking confirmed for {request.form['guest_name']} ({request.form['cabin_number']})."
        except Exception as exc:
            error = f"Database write error: {exc}"

    bookings = []
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM bookings ORDER BY id DESC LIMIT 50")
        bookings = cur.fetchall()
        cur.close()
        conn.close()
    except Exception as exc:
        error = f"Database read error: {exc}"

    return render_template_string(
        MAIN_TEMPLATE,
        bookings=bookings,
        message=message,
        error=error,
        env_label=ENV_LABEL,
        hostname=socket.gethostname(),
    )


@app.route("/staff", methods=["GET", "POST"])
def staff():
    authorized = False
    staff_user = None
    error = None

    if AUTH_MODE == "entra":
        # Azure Container Apps built-in auth injects this header
        staff_user = request.headers.get("X-MS-CLIENT-PRINCIPAL-NAME")
        if staff_user:
            authorized = True
        else:
            error = "Entra ID authentication header missing."
    else:
        if request.method == "POST":
            if request.form.get("username") == "admin" and request.form.get("password") == LEGACY_STAFF_PASSWORD:
                authorized = True
                staff_user = "admin (shared legacy account)"
            else:
                error = "Invalid legacy credentials."

    count = 0
    if authorized:
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute("SELECT COUNT(*) FROM bookings")
            count = cur.fetchone()[0]
            cur.close()
            conn.close()
        except Exception as exc:
            error = f"DB error: {exc}"

    return render_template_string(
        STAFF_TEMPLATE,
        authorized=authorized,
        staff_user=staff_user,
        auth_mode=AUTH_MODE,
        count=count,
        error=error,
    )


@app.route("/api/arrivals", methods=["GET"])
def api_arrivals():
    if ARRIVALS_API_KEY and request.headers.get("X-API-Key") != ARRIVALS_API_KEY:
        return jsonify({"error": "Unauthorized"}), 401

    park_filter = request.args.get("park")
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        if park_filter:
            cur.execute(
                """SELECT id, guest_name, park_code, cabin_number, arrival_date, departure_date, status
                   FROM bookings
                   WHERE park_code = %s AND (arrival_date = CURRENT_DATE OR status IN ('Arriving Today', 'Checked In'))
                   ORDER BY id ASC""",
                (park_filter,),
            )
        else:
            cur.execute(
                """SELECT id, guest_name, park_code, cabin_number, arrival_date, departure_date, status
                   FROM bookings
                   WHERE arrival_date = CURRENT_DATE OR status IN ('Arriving Today', 'Checked In')
                   ORDER BY id ASC"""
            )
        rows = cur.fetchall()
        cur.close()
        conn.close()
        return jsonify({
            "date": datetime.today().strftime("%Y-%m-%d"),
            "park": park_filter or "all",
            "count": len(rows),
            "arrivals": [
                {
                    "booking_id": r["id"],
                    "guest_name": r["guest_name"],
                    "park_code": r["park_code"],
                    "cabin_number": r["cabin_number"],
                    "arrival_date": str(r["arrival_date"]),
                    "departure_date": str(r["departure_date"]),
                    "status": r["status"],
                }
                for r in rows
            ],
        })
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


@app.route("/health", methods=["GET"])
def health():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        return jsonify({"status": "healthy", "host": socket.gethostname(), "database": "ok"}), 200
    except Exception as exc:
        return jsonify({"status": "unhealthy", "host": socket.gethostname(), "error": str(exc)}), 503


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
