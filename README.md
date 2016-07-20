# Testributor Ruby agent

This gem is the agent running on [Testributor](https://www.testributor.com) workers.
A new agent is being created in [Go](https://golang.org/). Among the reasons for this port are:

- We want to limit the external dependencies. The gem is dependant on Ruby,
  Redis, Git and a number of other gems. The new agent will only depend on Git
  to be present.

- We want the agent to run on various Operating Systems (Linux, Windows, Mac etc).
  Although it is possible to setup an working environment for this gem in any
  operating system, it is far from trivial for the average non Ruby developer
  out there. Since Testributor is a tool for programmers of various backgrounds
  and various languages, we should not force them to use Ruby specific tools.
  The new worker will be able to cross compile for the 3 major operating systems
  mentioned above and this will make installation and maintenance a lot simpler.

An other big advantage will be that we will be able to use any public Docker image
since we won't have any dependencies. It will make it easier for Testributor to
support a big number of technologies without lots of effort.

NOTE: The new agent will be released as open source as soon as it reaches a working state.

## Copyright

Copyright (c) 2016 - [Testributor.com](https://www.testributor.com), Dimitris Karakasilis (dimitris@testributor.com), Ilias Spyropoulos (ilias@testributor.com), Spyros Brilis (spyros@testributor.com), Pavlos Kallis (pavlos@testributor.com)
