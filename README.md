# DCS Code Challenge

## To Get Started (Assumes you have sfdx-cli installed):
* Please execute this command `sfdx force:source:deploy -m "ApexClass,ApexTrigger"` from the DCS folder to get started
* After the deploy is complete, execute this command `sfdx force:apex:test:run -r tap -t OpportunityTriggerTests`

## Some notes:
* I've found that there is an upper limit of records this logic can process (I encountered it at 500 updates) and to get around this a queueable could be implemented.
* Please forgive the coding style I used here as I optimized for time. I didn't use a domain style class and some of my lines are a bit long. I make it a habit not to comment my code and instead I opt for self documenting code.
* This code assumes no After Insert logic is needed. (Waiting on response from Abe on that)
* I added a try/catch around the inserts in OpportunityManager for completeness. The usefulness of the try/catch depends on how this manager would be used, I took a guess that it could be useful.


### Thanks!! :smiley: