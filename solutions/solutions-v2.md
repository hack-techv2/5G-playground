# Wireshark
## Wireshark Q1
Find the Subscriber Permanent Identifier (SUPI) / International Mobile Subscriber Identity (IMSI) of the User Equipment (UE).

### Solution
Filter the protocol by `nas-5gs`. NAS stands for Non-Access Stratum, a protocol that enables communication between 5G User Equipment (UE) and the 5G core network. This narrows the capture down to the relevant packets.

Take note of packets with Info columns which denote initiation, authentication or related terms. Examine the first packet in the filtered list, which indicates a registration request. Expand the fields for more information.
![image](https://github.com/user-attachments/assets/3bc7d524-c12f-4546-af2f-733f904af07a)

Referring to the diagram below, the SUPI / IMSI is a 15 - 16-digit string.
```
<------------------------------------- SUPI / IMSI ------------------------------------->
+---------------------+---------------------+-------------------------------------------+
| Mobile Country Code | Mobile Network Code | Mobile Subscription Identification Number |
| (MCC)               | (MNC)               | (MSIN)                                    |
| 3 digits            | 2 - 3 digits        | up to 10 digits                           |
+---------------------+---------------------+-------------------------------------------+
```
Piecing the information together, the entire SUPI / IMSI string is `999-70-5678123492`.

Alternatively, set the following protocol preferences in Wireshark under Edit --> Preferences... --> Protocols

Under HTTP2, specify the entire range of ports from `1-65535`. If Wireshark crashes, consider adding the ports range by range, comma-separated, e.g. `1-10000` and applying the settings before adding another range until all ports are specified.
![image](https://github.com/user-attachments/assets/7e4bd792-0e91-4db9-9c01-5034209f5133)

Under NAS-5GS, check the box for 'Try to detect and decode 5g-EA0 ciphered messages'.
![image](https://github.com/user-attachments/assets/1d3df23a-a7e4-4051-ab63-60d29a498f46)

After the settings have ben applied, using the `nas-5gs` protocol filter again, the SUPI / IMSI `999705678123492` can be seen in other packets more clearly as well.
![image](https://github.com/user-attachments/assets/bc628821-f4bd-4416-a188-ca29397caf8c)
