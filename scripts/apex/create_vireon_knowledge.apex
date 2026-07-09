// Creates and publishes the Vireon troubleshooting Knowledge articles that back
// the photo-diagnosis demo. Idempotent-ish: skips UrlNames that already exist.
List<Map<String, String>> defs = new List<Map<String, String>>();

defs.add(new Map<String, String>{
  'title' => 'Vireon Hub Router: Solid Amber Light Means No Internet',
  'url' => 'vireon-router-amber-light-no-internet',
  'summary' => 'A solid amber or orange status light on the Vireon Hub router means it is powered on but has no internet connection.',
  'body' => '<h2>Solid Amber Light on the Vireon Hub Router</h2><p>A solid amber (orange) status light means your router is powered on but cannot reach the internet.</p><ol><li>Check that the internet/WAN cable is firmly connected to the router and the wall.</li><li>Power-cycle: unplug the router for 30 seconds, plug it back in, and wait about 2 minutes for a solid white light.</li><li>Open the Vireon app to check for an outage in your area.</li><li>If the light is still amber after 5 minutes, contact Vireon support - your connection may need to be re-provisioned.</li></ol>'
});
defs.add(new Map<String, String>{
  'title' => 'Fiber ONT: Red LOS Light (Loss of Signal)',
  'url' => 'vireon-fiber-ont-los-red-light',
  'summary' => 'A red LOS light on the Vireon fiber ONT means the box has lost the optical signal from the network.',
  'body' => '<h2>Red LOS Light on the Fiber ONT</h2><p>LOS stands for Loss of Signal. A solid or blinking red LOS light means the optical network terminal is not receiving a fiber signal.</p><ol><li>Check that the green fiber optic cable is fully seated - never bend or kink it sharply.</li><li>Power-cycle the ONT: unplug it for 30 seconds and plug it back in.</li><li>Inspect the fiber cable for visible damage or tight bends.</li><li>If the LOS light stays red, the line usually needs a technician - contact Vireon support.</li></ol>'
});
defs.add(new Map<String, String>{
  'title' => 'Phone Shows No SIM or No Service',
  'url' => 'vireon-phone-no-sim-no-service',
  'summary' => 'Steps to fix a Vireon mobile phone that shows a No SIM Card alert or No Service in the status bar.',
  'body' => '<h2>No SIM / No Service on Your Phone</h2><p>When your phone shows No SIM Card or No Service, it cannot connect to the mobile network.</p><ol><li>Turn Airplane mode on for 10 seconds, then off again.</li><li>Restart the phone.</li><li>Reseat the physical SIM card, or for eSIM, remove and re-add the Vireon mobile plan.</li><li>Install any pending carrier settings update.</li><li>Confirm your line is active in your Vireon account.</li><li>If there is still no service, contact Vireon support.</li></ol>'
});
defs.add(new Map<String, String>{
  'title' => 'Vireon Stream Error VS-1004: Cannot Reach Servers',
  'url' => 'vireon-stream-error-vs-1004',
  'summary' => 'Error VS-1004 on Vireon Stream means the device cannot reach the streaming servers, usually a connection problem.',
  'body' => '<h2>Vireon Stream Error VS-1004</h2><p>Error code VS-1004 means your device could not reach the Vireon Stream servers. This is almost always a network connection issue.</p><ol><li>Confirm other apps and websites work on your network.</li><li>Restart the streaming box (unplug for 30 seconds).</li><li>Move the box closer to the router or check your Wi-Fi signal.</li><li>Update the Vireon Stream app to the latest version.</li><li>Sign out of Vireon Stream and sign back in.</li><li>If VS-1004 persists, contact Vireon support.</li></ol>'
});
defs.add(new Map<String, String>{
  'title' => 'Vireon Stream App Will Not Load on Smart TV',
  'url' => 'vireon-stream-app-not-available-tv',
  'summary' => 'Fix the Vireon Stream app when it crashes or shows This app is not available right now on your smart TV.',
  'body' => '<h2>Vireon Stream App Crashing on Smart TV</h2><p>If the Vireon Stream app will not open, crashes, or shows a message that the app is not available, try these steps.</p><ol><li>Force-close the app and reopen it.</li><li>Restart the TV by unplugging it for 30 seconds.</li><li>Check for both app updates and TV software updates.</li><li>Uninstall and reinstall the Vireon Stream app.</li><li>Confirm the TV has a working internet connection.</li><li>If it keeps crashing, contact Vireon support.</li></ol>'
});
defs.add(new Map<String, String>{
  'title' => 'TV Shows No Signal from Vireon Set-Top Box',
  'url' => 'vireon-set-top-box-no-signal',
  'summary' => 'What to do when your TV displays No Signal or Searching for signal with a Vireon cable set-top box.',
  'body' => '<h2>No Signal from the Set-Top Box</h2><p>A No Signal or Searching for signal message means the TV is not receiving a picture from your Vireon set-top box.</p><ol><li>Make sure the TV is set to the correct HDMI input.</li><li>Check that the HDMI and coax cables are firmly connected at both ends.</li><li>Power-cycle the set-top box: unplug it for 30 seconds and plug it back in.</li><li>Confirm the box is powered on - the front display should show the time.</li><li>If you still see No Signal, contact Vireon support.</li></ol>'
});
defs.add(new Map<String, String>{
  'title' => 'Vireon Smart Thermostat: Error Code E5',
  'url' => 'vireon-thermostat-error-e5',
  'summary' => 'Error E5 on the Vireon smart thermostat indicates a wiring or sensor fault with the HVAC connection.',
  'body' => '<h2>Vireon Smart Thermostat Error E5</h2><p>Error E5 usually means the thermostat has a wiring or sensor fault, or has lost its connection to the HVAC system.</p><ol><li>Turn off the HVAC system at the breaker for one minute, then turn it back on.</li><li>Gently remove the thermostat from its base and reseat it firmly.</li><li>Check that the C (common) wire is properly connected.</li><li>Restart the thermostat from its settings menu.</li><li>If E5 remains, contact Vireon support - a technician may be needed.</li></ol>'
});
defs.add(new Map<String, String>{
  'title' => 'Vireon Smart Home Hub: Solid Red Ring Means Offline',
  'url' => 'vireon-smart-hub-red-ring-offline',
  'summary' => 'A solid red ring on the Vireon smart home hub means it is offline and not connected to your network.',
  'body' => '<h2>Solid Red Ring on the Smart Home Hub</h2><p>A solid red light ring means your Vireon smart home hub is offline and cannot connect to your Wi-Fi network.</p><ol><li>Confirm your Wi-Fi and internet are working on another device.</li><li>Move the hub closer to your router.</li><li>Power-cycle the hub: unplug it for 30 seconds and plug it back in.</li><li>Re-run setup in the Vireon Home app to reconnect it to Wi-Fi.</li><li>If the ring stays red, contact Vireon support.</li></ol>'
});
defs.add(new Map<String, String>{
  'title' => 'Vireon Band or Watch Not Charging (Red Battery)',
  'url' => 'vireon-wearable-not-charging',
  'summary' => 'Fix a Vireon wearable that will not charge or shows a red empty battery or charging fault icon.',
  'body' => '<h2>Vireon Wearable Will Not Charge</h2><p>If your Vireon band or watch shows a red empty battery icon or will not charge, try these steps.</p><ol><li>Clean the metal charging contacts on both the wearable and the charging cradle.</li><li>Reseat the wearable firmly on the magnetic charger until it clicks.</li><li>Try a different USB port, adapter, and cable.</li><li>Let it charge for 30 minutes, then force-restart the device.</li><li>If it still will not charge, contact Vireon support.</li></ol>'
});

// Skip any that already exist (by UrlName).
Set<String> urls = new Set<String>();
for (Map<String, String> d : defs) { urls.add(d.get('url')); }
Set<String> existing = new Set<String>();
for (Knowledge__kav k : [SELECT UrlName FROM Knowledge__kav WHERE UrlName IN :urls]) {
  existing.add(k.UrlName);
}

List<Knowledge__kav> toInsert = new List<Knowledge__kav>();
for (Map<String, String> d : defs) {
  if (existing.contains(d.get('url'))) { continue; }
  toInsert.add(new Knowledge__kav(
    Title = d.get('title'),
    UrlName = d.get('url'),
    Summary = d.get('summary'),
    FAQ_Answer__c = d.get('body'),
    Language = 'en_US'
  ));
}

if (toInsert.isEmpty()) {
  System.debug('All Vireon articles already exist. Nothing to insert.');
} else {
  insert toInsert;
  Set<Id> versionIds = new Map<Id, Knowledge__kav>(toInsert).keySet();
  Integer published = 0;
  for (Knowledge__kav k : [SELECT Id, KnowledgeArticleId, Title FROM Knowledge__kav WHERE Id IN :versionIds]) {
    try {
      KbManagement.PublishingService.publishArticle(k.KnowledgeArticleId, true);
      published++;
    } catch (Exception e) {
      System.debug('Publish failed for ' + k.Title + ': ' + e.getMessage());
    }
  }
  System.debug('RESULT inserted=' + toInsert.size() + ' published=' + published);
}
