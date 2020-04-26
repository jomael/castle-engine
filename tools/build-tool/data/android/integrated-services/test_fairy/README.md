# test_fairy

This service integrates _Castle Game Engine_ applications with [Test Fairy](https://www.testfairy.com/). It's a nice way to distribute mobile applications to your testers, gather logs, feedback etc.

Using this service is *not* necessary to use [Test Fairy](https://www.testfairy.com/) in a basic way. That is, you can distribute your apps through TestFairy without integrating their SDK.

Still, using this service enhances the experience. You will receive logs, videos, user can submit feedback (from the mobile application to your TestFairy application) and more. There's no need to do anything on the Pascal side, you merely use this service.

To see the logs, make sure to turn _"Application logs"_ in the _"Metrics"_ section in the _"Insights"_ tab of your application [Build Settings](https://docs.testfairy.com/Getting_Started/Version_Settings.html). This can be done after the app was uploaded or the first session performed. They are enabled by default, so usually you don't have to do anything.

## Parameters

You need to specify additional parameters inside `CastleEngineManifest.xml` when using this service:

~~~~xml
<service name="test_fairy">
  <parameter key="domain" value="xxxxxx" />
  <parameter key="sdk_app_token" value="SDK-yyyyyy" />
</service>
~~~~

The "domain" parameter above is the initial component of your TestFairy domain name. E.g. if you login to `https://catgames.testfairy.com/` , then use `<parameter name="domain" name="catgames" />`.

Get your "SDK App Token" from your dashboard settings (accessible like `https://catgames.testfairy.com/settings` , but make sure to change the domain in this URL).
