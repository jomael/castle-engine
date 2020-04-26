# test_fairy

This service integrates _Castle Game Engine_ applications with [Test Fairy](https://www.testfairy.com/). It's a nice way to distribute mobile applications to your testers, gather logs, feedback etc.

On iOS, it's a nice alternative to TestFlight. Unlike TestFlight, you do not need Apple to accept your test applications (but you will still need to sign them with a developer key signed by Apple).

Using this service is *not* necessary to use [Test Fairy](https://www.testfairy.com/) in a basic way. That is, you can distribute your apps through TestFairy without integrating their SDK.

Still, using this service enhances the experience. You will receive logs, videos, user can submit feedback (from the mobile application to your TestFairy application) and more. There's no need to do anything on the Pascal side, you merely use this service. See https://docs.testfairy.com/iOS_SDK/Integrating_iOS_SDK.html for a description of benefits.

Use the `CastleTestFairy` unit and call `TTestFairy.InitializeRemoteLogging;` to initialize remote logging to TestFairy on iOS. This way you will see all CGE logs in the TestFairy session report. This is necessary now only on iOS (on Android, all logs are automatically collected), but you can safely call it on all platforms.

Note about `CastleTestFairy` unit: on iOS, use it *only* if you use `test_fairy` service, otherwise the code will not even link.

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
