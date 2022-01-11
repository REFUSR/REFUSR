---
title: "An analysis of the security and code quality of OpenPLC"
author: "Stephen Okay"
date: 2021-12-28
tags: [code, openplc, python, plc, refusr]
abstract: "An evaluation of the quality of the OpenPLC codebase, including a potential security issue."
---

Introduction
------------

The OpenPLC project is an Open Source IEC 61131-3-compliant PLC controller. It has a sizable(?) following/userbase and is cited frequently in the academic and industry literature. Written in C++ and Python, it provides a run-time container to run control programs written in Ladder Logic and Structured Text. While it can run on any modern Linux system, it is primarily targeted at embedded devices like the Raspberry Pi family of Single-Board Computers(SBCs).

In the course of our work with the OpenPLC system, we have noticed a number of bugs in the code, particularly the `webserver.py` program which could make the system open to denial-of-service if someone had shell access on the system. We are in contact with the OpenPLC project lead and in conversation with them to determine their awareness of the defects and their plans for remediation.

I started digging into the OpenPLC code following a filesystem corruption problem on the Raspberry Pi 4 I had OpenPLC installed on for use with REFUSR. The USB C-cable got inadvertently yanked and that scribbled over the SD card on the Pi. When I plugged it back in, I noticed that the `openplc.service` had failed to start on boot and also refused to start when invoked from inside the shell. So I started digging through the Python code and came up with the observations below.

System Design
-------------

The OpenPLC system layout is an source tree retrieved from Github with the following directory structure:

```
* OpenPLC_v3
* ├── documentation
* │   └── EtherNet-IP
* ├── utils
* │   ├── apt-cyg
* │   ├── dnp3_src
* │   ├── glue_generator_src
* │   ├── libmodbus_src
* │   ├── matiec_src
* │   └── st_optimizer_src
* └── webserver
*     ├── core
*     ├── scripts
*     ├── lib
*     ├── static
*     └── st_files
```

The main code lives under webserver with the core PLC runtime found under core. Structured Text(ST) programs which the OpenPLC server runs are in st_files. There are helper scripts under scripts and the ST/LL/NN compiler lives under utils.

Installation:
-------------

Installation is done via git clone into an area that the end-user has permissions to. Typically this would be to something like `/home/bob` or `/home/alice`. As we can see above, OpenPLC_v3 is the top-level directory. After cloning the OpenPLC repo, you run the ./install.sh script to compile the source tree and set it up to run as a `systemd` service.

Detailed instructions can be found on the OpenPLC website:
https://www.openplcproject.com/runtime/raspberry-pi/

Bugs
----

### Bug: active_program

The main bug we discovered is found in the `webserver.py` script. At start, it reads in `$OPENPLC/webserver/active_program` and uses the text it finds in there as part of an **SQL SELECT** statement it builds to query the `openplc.db` SQLite database. If it finds a matching entry under the **'Program'** table, it proceeds to also query the **'Settings'** table for configuration parameters for the OpenPLC server and runtime and launches the webserver front-end which is written in the Flask framework.

If the text in `$OPENPLCDIR/webserver/active_program` is not found in `openplc.db` via the **SELECT**, `webserver.py` terminates with the following error:
```
Traceback (most recent call last):
  File "webserver.py", line 2386, in <module>
    openplc_runtime.project_name = str(row[1])
TypeError: 'NoneType' object has no attribute '__getitem__'
```

### Bug: 'Settings' Table and "Start_run_mode" value

The ***'Settings'*** table in `openplc.db` contains a number of default parameters used when the OpenPLC server is running. One of these is the key/value pair **'Start_run_mode'**. This needs to have the value of **'true'** as a text string in order for the server to start. There is an explicit check in this chunk of code for this:
```
    cur.execute("SELECT * FROM Settings")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    print(rows)
    for row in rows:
    if (row[0] == "Start_run_mode"):
       start_run = str(row[1])

       if (start_run == 'true'):
          print("Initializing OpenPLC in RUN mode...")
          openplc_runtime.start_runtime()
          time.sleep(1)
          configure_runtime()

     app.run(debug=False, host='0.0.0.0', threaded=True, port=8080)
```

As you can see, if **start_run** is not **'true'**, the server is not started. The default value of this setting is **'false'** in the `openplc.db` that is installed by default. I've hit this at least once or twice, but given the lack of error checking in code above this block, I haven't tried too hard to reproduce. Also notice that there is no handling for the case where start_run is **‘false’** or **‘0’** or **False** or anything but **‘true’**.

### Repetition:

A lot of this code is reproduced in the configure_runtime method so it's not entirely clear what these startup checks are actually doing at a practical level other than providing opportunities for the server not to start.

### General appraisal:

The most polite and professional assessment that can be made about the front-end and/or non-PLC-compiling/running code is that it's naively written with little attention to best practices around writing robust, reliable, maintainable code. There is literacy in Python, Flask, etc. and I've run it long enough to be able to say that once running it executes and stays up, but it really truly is not meant to be run in anything other than, say, an internal lab with limited/no outside connectivity. There are enough points to pick on that a full security analysis is not worth the time. Just calling `openplc_runtime.start_runtime()` at the start of `__main__` and deleting everything else from the webserver.py code would fix a lot of this.

Future Directions:
1. Ignore everything and just let OpenPLC putter along. There's not one bug or vuln, but the whole thing. Thiago Alves, the creator of OpenPLC is just a one-man show and seems to be aware that there are some bugs and deficiencies in the system and has scoped out the use of the system as not being meant for production use.

2. Take the LL/ST runtime and compiler bits and fork it to rewrite a proper front-end that might be useful in something other than isolated learning labs. Include things like support for Frida and other tools that we think might be useful. Work on squeezing that effort into one of the SBIR grants.

3. Some variant of the above two points.

I’m interested in any feedback our team might have on this.
