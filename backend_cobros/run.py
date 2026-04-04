#!/usr/bin/env python
import subprocess
import sys

if __name__ == "__main__":
    subprocess.run([
        sys.executable, "-m", "uvicorn", 
        "main:app", 
        "--host", "0.0.0.0", 
        "--port", "8001"
    ], cwd="c:\\Users\\RICARDO\\Desktop\\proyecto_cobros\\backend_cobros")
