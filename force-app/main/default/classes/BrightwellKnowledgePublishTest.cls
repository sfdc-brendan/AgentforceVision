@isTest
private class BrightwellKnowledgePublishTest {

    private static RestRequest postBody(Object body) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/brightwell/knowledge';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(body));
        RestContext.request = req;
        RestContext.response = new RestResponse();
        return req;
    }

    @isTest
    static void createsDraftArticle() {
        postBody(new Map<String, Object>{
            'title' => 'Dishwasher LE Error Fix',
            'summary' => 'Resolve the LE error on your dishwasher',
            'question' => 'Why is my dishwasher showing LE?',
            'answerHtml' => '<h2>Steps</h2><ol><li>Power cycle the unit</li></ol>',
            'keywords' => 'dishwasher le error drain'
        });

        Test.startTest();
        BrightwellKnowledgePublish.createArticle();
        Test.stopTest();

        System.assertEquals(201, RestContext.response.statusCode, RestContext.response.responseBody.toString());
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Knowledge__kav WHERE Title = 'Dishwasher LE Error Fix'],
            'A draft article should be created'
        );
    }

    @isTest
    static void rejectsMissingFields() {
        postBody(new Map<String, Object>{ 'summary' => 'no title or body' });
        BrightwellKnowledgePublish.createArticle();
        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void detectsDuplicate() {
        Knowledge__kav existing = new Knowledge__kav(
            Title = 'Fridge Not Cooling Fix',
            UrlName = 'fridge-not-cooling-' + String.valueOf(Datetime.now().getTime()),
            Language = 'en_US'
        );
        insert existing;

        // Force SOSL to return the existing article so the dedupe path runs.
        Test.setFixedSearchResults(new List<Id>{ existing.Id });

        postBody(new Map<String, Object>{
            'title' => 'Fridge Not Cooling Fix Guide',
            'answerHtml' => '<p>steps</p>',
            'keywords' => 'fridge not cooling'
        });
        BrightwellKnowledgePublish.createArticle();

        Map<String, Object> out =
            (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        System.assertEquals(false, out.get('created'), 'Duplicate should not create a new article');
        System.assertEquals('duplicate', out.get('reason'));
    }
}
