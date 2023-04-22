# Wazuh Rules 

```yaml
---
global:
  log_format: "syslog"
  log_level: 1

ruleset:
  decoder_files:
    - "web3_decoders.xml"

  rule_files:
    - "web3_rules.xml"

decoders:
  - "web3_decoders.xml":
    - name: "web3"
      program_name: "^web3$"
      regex: "^(\S+) (\S+) (\S+) (\S+): (.+)$"
      order: "srcip, protocol, dstip, dstport, message"

rules:
  - "web3_rules.xml":
    - rule:
        id: 100001
        level: 5
        description: "Web3 application error"
        match: "error"
        group: "web3"
        options:
          - "no_full_log"
    - rule:
        id: 100002
        level: 3
        description: "Web3 application warning"
        match: "warning"
        group: "web3"
        options:
          - "no_full_log"
    - rule:
        id: 100003
        level: 2
        description: "Web3 application information"
        match: "info"
        group: "web3"
        options:
          - "no_full_log"
    - rule:
        id: 100004
        level: 10
        description: "Web3 application critical security event"
        match: "critical"
        group: "web3"
        options:
          - "no_full_log"
    - rule:
        id: 100005
        level: 7
        description: "Web3 application security event"
        match: "security"
        group: "web3"
        options:
          - "no_full_log"
```

This configuration file sets up a decoder for web3 applications and defines various rules for different severity levels of log messages. You can modify the rules and decoders based on your specific needs and the web3 applications you are monitoring.

Additionally, don't forget to integrate Wazuh with other components in your infrastructure, such as Elasticsearch for log storage and analysis, and Kibana for visualization and monitoring.