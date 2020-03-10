# deployscript-nessus-scanner
This is a simple script to deploy a Nessus Scanner via docker, connect it to Tenable.io, and add the scanner to a group via the Tenable.io API. 

This image is meant to be used on a Ubuntu or Debian based docker host, although it can be modified to sute your needs. 

Docker image:
https://hub.docker.com/r/stevemcgrath/nessus_scanner

If you have any questions about how to run this script, the instructions are included in the script. Anything you need to configure will be identified by the script itself.

I intend to break this out into an actual deployment methodology, but for short term, this covers my needs.
