# dumuzid
Collection of bash scripts to monitor a system

The initial design does not aim to be a 24/7 paging sytem. Rather

* Notify immediately on seeing a problem by email
* But don't email too often afterwards (once a day to once an hour)

If a script in the directory returns non-zero, the output sent by the script (in standard output) will be printed and sent by email.

Thus, the required design for adding monitoring features is simple:
* If no error or warning, return 0
* If there is an error or warning, return non zero and print message to standard output

The name dumuzid comes from the Sumerian diety of the same name, "Dumuzid the Shepherd".
