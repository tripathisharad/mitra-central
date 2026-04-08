import pyodbc
import logging
import sys

# --- CONFIGURATION ---
DSN_NAME = 'yashlocal'
USER_ID = 'admin'
PASSWORD = 'your_password_here'  # Replace with your actual password

# UPDATED QUERY:
# 1. Added "PUB." schema prefix (Required for QAD/Progress)
# 2. Changed "LIMIT 50" to "TOP 50" (Progress specific syntax)
SQL_QUERY = """
SELECT TOP 50
    pt.pt_part AS "Part Number", 
    pt.pt_desc1 AS "Part Description", 
    inv.in_site AS "Site", 
    inv.in_qty_oh AS "Quantity On Hand", 
    pt.pt_sfty_stk AS "Safety Stock" 
FROM PUB.in_mstr AS inv 
JOIN PUB.pt_mstr AS pt ON inv.in_part = pt.pt_part AND inv.in_domain = pt.pt_domain 
WHERE inv.in_domain = '10USA' 
  AND pt.pt_domain = '10USA' 
  AND inv.in_qty_oh < pt.pt_sfty_stk
"""

# --- LOGGING SETUP ---
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("qad_query.log"),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

def run_test():
    conn = None
    try:
        logger.info(f"Connecting to DSN: {DSN_NAME} (Database: qaddb)...")
        
        # Connection string
        conn_str = f'DSN={DSN_NAME};UID={USER_ID};PWD={PASSWORD}'
        conn = pyodbc.connect(conn_str, autocommit=True)
        logger.info("Connection established successfully.")

        cursor = conn.cursor()

        # Step 1: Optional but recommended - force the schema to PUB just in case
        logger.info("Setting default schema to 'PUB'...")
        cursor.execute("SET SCHEMA 'PUB'")

        # Step 2: Execute the main query
        logger.info("Executing the inventory check query...")
        cursor.execute(SQL_QUERY)
        
        rows = cursor.fetchall()
        
        # Step 3: Log results
        if not rows:
            logger.warning("Query returned 0 rows. Check if 'INDIA' domain exists or if filters are too strict.")
        else:
            logger.info(f"Success! Retrieved {len(rows)} records.")
            
            # Print column headers
            columns = [column[0] for column in cursor.description]
            header = " | ".join(columns)
            print("\n" + header)
            print("-" * len(header))
            
            # Print first 5 rows to console
            for row in rows[:5]:
                print(" | ".join(str(val) for val in row))
            
            if len(rows) > 5:
                print(f"... and {len(rows)-5} more rows.")

    except pyodbc.Error as e:
        # Extract specific Progress error codes if possible
        sqlstate = e.args[0]
        if sqlstate == '42S02':
            logger.error("ERROR: Table not found. Ensure the table names are correct and 'PUB.' is used.")
        elif sqlstate == '42000':
            logger.error("ERROR: Syntax error. Your Progress version might not support 'TOP'. Try removing it to test.")
        else:
            logger.error(f"ODBC/Database Error: {e}")
            
    except Exception as e:
        logger.error(f"General Script Error: {e}")
        
    finally:
        if conn:
            conn.close()
            logger.info("Connection closed.")

if __name__ == "__main__":
    run_test()