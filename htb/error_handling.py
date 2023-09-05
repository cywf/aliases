# This script adds the following functionality to the previous scripts:
# 
# 1. Error Logging:
# 
# - The log_error function will log any errors to a file named error_log.txt. If any subprocess command fails, the error will be captured and logged.
# 
# 2. ASCII Loading Bar:
# 
# - The loading_bar function will display a simple ASCII loading bar to give the user a sense of progress. It will fill up over a specified duration (default is 5 seconds).
# 
# 3. Updated Main Function:
# 
# - Each major step is now wrapped in a try and except block. If an error occurs, it's logged, and the script continues to the next step. After each step, a loading bar is displayed to indicate progress.

import time
from datetime import datetime

# ... [Previous functions]

def log_error(error, step, log_file="error_log.txt"):
    """Log the error to a file."""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    with open(log_file, "a") as file:
        file.write(f"{timestamp} - Error during {step}: {error}\n")

def loading_bar(duration=5, message="Processing"):
    """Display an ASCII loading bar."""
    for i in range(duration):
        print(f"\r{message} [{'#' * (i+1)}{'.' * (duration - i - 1)}] {((i+1)/duration)*100:.0f}%", end="")
        time.sleep(1)
    print()  # Move to the next line after loading bar completes

# Update the main function
def main():
    error_count = 0
    handle, machine_name, machine_ip, machine_type = get_user_input()
    base_dir = setup_directory_structure(machine_name)
    loading_bar(message="Setting up directory structure")
    
    try:
        install_tools(base_dir)
        loading_bar(message="Installing tools")
    except Exception as e:
        log_error(e, "install_tools")
        error_count += 1

    if not machine_type:
        try:
            machine_type = initial_nmap_scan(machine_ip, base_dir)
            loading_bar(message="Running initial Nmap scan")
        except Exception as e:
            log_error(e, "initial_nmap_scan")
            error_count += 1
    else:
        print(f"Machine type provided as: {machine_type}")

    try:
        advanced_nmap_scan(machine_ip, machine_type, base_dir)
        loading_bar(message="Running advanced Nmap scan")
    except Exception as e:
        log_error(e, "advanced_nmap_scan")
        error_count += 1

    try:
        generate_payloads(machine_ip, machine_type, base_dir)
        loading_bar(message="Generating payloads")
    except Exception as e:
        log_error(e, "generate_payloads")
        error_count += 1

    print("\nAll tasks completed!")
    if error_count:
        print(f"{error_count} errors occurred. Check error_log.txt for details.")
    else:
        print("No errors occurred.")

if __name__ == "__main__":
    main()
