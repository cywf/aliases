# This script will:

# 1. Prompt the user for their handle, machine name, and machine IP.
# 2. Ask the user if they know the machine type.
# 3. Set up the directory structure based on the machine name.
# 4. Generate an info.md file in the notes directory.

import os
import datetime

def get_user_input():
    """Get user input for handle, machine name, and IP."""
    handle = input("Enter your handle: ")
    machine_name = input("Enter the name of the machine you are pentesting: ")
    machine_ip = input("Enter the IP of the machine you are pentesting: ")
    machine_type = input("Do you know the machine type (Windows/Linux)? If not, just press enter: ")
    return handle, machine_name, machine_ip, machine_type

def setup_directory_structure(machine_name):
    """Set up the directory structure for the machine."""
    base_dir = os.path.join("htb", machine_name)
    subdirs = ["tools", "machines", "nmap", "notes", "loot", "shells", "payloads"]
    
    # Create base directory
    if not os.path.exists(base_dir):
        os.makedirs(base_dir)
    
    # Create subdirectories
    for subdir in subdirs:
        os.makedirs(os.path.join(base_dir, subdir), exist_ok=True)

    return base_dir

def generate_info_md(handle, machine_name, machine_ip, base_dir):
    """Generate the info.md file in the notes directory."""
    notes_dir = os.path.join(base_dir, "notes")
    
    current_time = datetime.datetime.now()
    date_str = current_time.strftime("%Y-%m-%d")
    time_str = current_time.strftime("%H:%M:%S")
    
    info_content = f"""
# ---------------------- #
#   MACHINE INFO         #
#                        #
# IP: {machine_ip}       #
# Name: {handle}         #
# Box: {machine_name}    #
# Date: {date_str}       #
# Time: {time_str}       #
# ---------------------- #

# ------------------ #
# NMAP RESULT        #
# ------------------ #
"""
    
    with open(os.path.join(notes_dir, "info.md"), "w") as f:
        f.write(info_content)

def main():
    handle, machine_name, machine_ip, machine_type = get_user_input()
    base_dir = setup_directory_structure(machine_name)
    generate_info_md(handle, machine_name, machine_ip, base_dir)
    print(f"Directory structure set up at: {base_dir}")

if __name__ == "__main__":
    main()
