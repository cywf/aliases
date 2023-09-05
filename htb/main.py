import error_handling
import nmap_payload_gen
import setup
import tools

def main():
    # Get user input
    handle, machine_name, machine_ip, machine_type = setup.get_user_input()

    # Setup directory structure
    base_dir = setup.setup_directory_structure(machine_name)
    error_handling.loading_bar(message="Setting up directory structure")

    # Install tools
    try:
        tools.install_tools(base_dir)
        error_handling.loading_bar(message="Installing tools")
    except Exception as e:
        error_handling.log_error(e, "install_tools")

    # Determine machine type if not provided
    if not machine_type:
        try:
            machine_type = nmap_payload_gen.initial_nmap_scan(machine_ip, base_dir)
            error_handling.loading_bar(message="Running initial Nmap scan")
        except Exception as e:
            error_handling.log_error(e, "initial_nmap_scan")
    else:
        print(f"Machine type provided as: {machine_type}")

    # Advanced Nmap scan and payload generation
    try:
        nmap_payload_gen.advanced_nmap_scan(machine_ip, machine_type, base_dir)
        error_handling.loading_bar(message="Running advanced Nmap scan")
    except Exception as e:
        error_handling.log_error(e, "advanced_nmap_scan")

    try:
        nmap_payload_gen.generate_payloads(machine_ip, machine_type, base_dir)
        error_handling.loading_bar(message="Generating payloads")
    except Exception as e:
        error_handling.log_error(e, "generate_payloads")

    print("\nAll tasks completed! Check error_log.txt for any errors.")

if __name__ == "__main__":
    main()
