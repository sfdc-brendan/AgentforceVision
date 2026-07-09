@IsTest
private class AgentforceVisionKnowledgeActionTest {
    private class StubSearcher implements AgentforceVisionKnowledgeAction.Searcher {
        public String lastTerms;
        public List<Knowledge__kav> toReturn = new List<Knowledge__kav>();
        public List<Knowledge__kav> search(String terms, Integer maxArticles) {
            this.lastTerms = terms;
            return toReturn;
        }
    }

    private static AgentforceVisionKnowledgeAction.Request req(String keywords) {
        AgentforceVisionKnowledgeAction.Request r = new AgentforceVisionKnowledgeAction.Request();
        r.keywords = keywords;
        return r;
    }

    @IsTest
    static void formatsMatchingArticles() {
        StubSearcher stub = new StubSearcher();
        stub.toReturn = new List<Knowledge__kav>{
            new Knowledge__kav(
                Title = 'In-Room Thermostat Troubleshooting',
                Summary = 'Fix common thermostat errors.',
                UrlName = 'thermostat-troubleshooting',
                FAQ_Answer__c = '<h2>Reset</h2><p>Hold the power button for 10 seconds.</p>'
            )
        };
        AgentforceVisionKnowledgeAction.searcher = stub;

        Test.startTest();
        List<AgentforceVisionKnowledgeAction.Response> results =
            AgentforceVisionKnowledgeAction.search(new List<AgentforceVisionKnowledgeAction.Request>{
                req('thermostat, E5 error')
            });
        Test.stopTest();

        AgentforceVisionKnowledgeAction.Response res = results[0];
        System.assertEquals(1, res.articleCount);
        System.assert(res.articles.contains('In-Room Thermostat Troubleshooting'), 'Title should appear');
        System.assert(res.articles.contains('Hold the power button'), 'HTML body should be stripped and included');
        System.assert(!res.articles.contains('<h2>'), 'HTML tags should be stripped');
        System.assert(res.articles.contains('/article/thermostat-troubleshooting'), 'Link should appear');
        System.assertEquals('thermostat, E5 error', stub.lastTerms, 'Commas are valid SOSL search text and retained');
    }

    @IsTest
    static void handlesNoMatches() {
        StubSearcher stub = new StubSearcher();
        AgentforceVisionKnowledgeAction.searcher = stub;

        Test.startTest();
        List<AgentforceVisionKnowledgeAction.Response> results =
            AgentforceVisionKnowledgeAction.search(new List<AgentforceVisionKnowledgeAction.Request>{
                req('nonexistent problem')
            });
        Test.stopTest();

        System.assertEquals(0, results[0].articleCount);
        System.assert(results[0].message.contains('No published Knowledge articles'));
    }

    @IsTest
    static void handlesBlankKeywords() {
        Test.startTest();
        List<AgentforceVisionKnowledgeAction.Response> results =
            AgentforceVisionKnowledgeAction.search(new List<AgentforceVisionKnowledgeAction.Request>{
                req('   ')
            });
        Test.stopTest();

        System.assertEquals(0, results[0].articleCount);
        System.assertEquals('No search keywords were provided.', results[0].message);
    }

    @IsTest
    static void soslSearcherRunsWithoutError() {
        // Exercises the real SOSL path (fixed empty results) for coverage.
        Test.setFixedSearchResults(new List<Id>());
        AgentforceVisionKnowledgeAction.Searcher real = new AgentforceVisionKnowledgeAction.SoslSearcher();
        Test.startTest();
        List<Knowledge__kav> found = real.search('wifi', 3);
        Test.stopTest();
        System.assertEquals(0, found.size());
    }
}
