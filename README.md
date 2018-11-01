# aem-test-session-close

Project for testing Session closure when closing ResourceResolver.

1. run ```./deploy```
2. open [http://localhost:4502/content/aemdesign/test.html](http://localhost:4502/content/aemdesign/test.html)
3. open [http://localhost:4502/system/console/jmx](http://localhost:4502/system/console/jmx) and search for SessionStatistics
4. press ```RELOAD``` a few times
5. in list of Sessions List check ```admin``` session count
6. press ```RELOAD``` a few more times and see if ```admin``` session count increases
7. press ```Do Unsafe Session Open```
8. verify thar ```QueryString: unsafesessions=true```
9. press ```RELOAD``` a few more times and see if ```admin``` session count increases

