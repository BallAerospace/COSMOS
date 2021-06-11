# Testing COSMOS with Cypress

NOTE: All commands are assumed to be executed from this (cypress) directory unless otherwise noted

1.  Start cosmos

        COSMOS> cosmos-control.bat start

1.  Open COSMOS in your browser. It should take you to the login screen. Set the password to "password"

1.  Install testing dependencies with yarn

        cypress> yarn

1.  _[Optional]_ Fix istanbul/nyc coverage source lookups (use `fixlinux` if not on Windows).
    Tests will run successfully without this step and you will get coverage statistics, but line-by-line coverage won't work.

        cypress> yarn run fixwindows

1.  Open Cypress and run tests

        cypress> yarn run cypress open

Code coverage reports can be viewed at [cypress/coverage/lcov-report/index.html](./coverage/lcov-report/index.html)
