/**
 * Agentforce Vision - Find Troubleshooting Articles action.
 *
 * Takes the keywords produced by image analysis and searches published Lightning
 * Knowledge (Knowledge__kav) for matching troubleshooting articles. Returns the
 * article content so the agent can ground its troubleshooting steps in real
 * Knowledge rather than inventing them.
 */
public with sharing class AgentforceVisionKnowledgeAction {
    @TestVisible
    private static final Integer MAX_ARTICLES = 3;

    // Wider SOSL pool so the relevance guard has candidates to rank and filter
    // before trimming down to MAX_ARTICLES.
    @TestVisible
    private static final Integer CANDIDATE_POOL = 20;

    // Seam so tests can supply deterministic articles without depending on SOSL
    // fixed results and article publishing mechanics.
    @TestVisible
    private static Searcher searcher = new SoslSearcher();

    public class Request {
        @InvocableVariable(
            label='Search Keywords'
            description='Keywords or a short phrase describing the problem, typically from the image analysis.'
            required=true
        )
        public String keywords;
    }

    public class Response {
        @InvocableVariable(label='Articles Found')
        public Integer articleCount;

        @InvocableVariable(label='Grounded Article Content')
        public String articles;

        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(
        label='Agentforce Vision: Find Troubleshooting Articles'
        description='Searches published Knowledge articles for troubleshooting guidance matching the supplied keywords.'
    )
    public static List<Response> search(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            results.add(processOne(req));
        }
        return results;
    }

    private static Response processOne(Request req) {
        Response res = new Response();
        res.articleCount = 0;

        String terms = sanitize(req == null ? null : req.keywords);
        if (String.isBlank(terms)) {
            res.articles = '';
            res.message = 'No search keywords were provided.';
            return res;
        }

        List<Knowledge__kav> candidates = searcher.search(terms, CANDIDATE_POOL);
        // Drop keyword-only collisions so the agent grounds its steps only in
        // articles that are genuinely about the diagnosed item.
        List<Knowledge__kav> articles = VisionArticleRelevance.selectRelevant(
            req.keywords,
            candidates,
            MAX_ARTICLES
        );

        if (articles == null || articles.isEmpty()) {
            res.articles = '';
            res.message = 'No published Knowledge articles matched "' + terms + '".';
            return res;
        }

        res.articleCount = articles.size();
        res.articles = format(articles);
        res.message = articles.size() + ' article(s) found.';
        return res;
    }

    /** Abstraction over the Knowledge search so it can be mocked in tests. */
    public interface Searcher {
        List<Knowledge__kav> search(String terms, Integer maxArticles);
    }

    public class SoslSearcher implements Searcher {
        public List<Knowledge__kav> search(String terms, Integer maxArticles) {
            // No ORDER BY: let SOSL return articles in search-relevance order.
            String soslQuery = 'FIND :terms IN ALL FIELDS RETURNING Knowledge__kav('
                + 'Id, Title, Summary, UrlName, ArticleNumber, FAQ_Answer__c '
                + 'WHERE PublishStatus = \'Online\' AND Language = \'en_US\' AND IsLatestVersion = true) '
                + 'LIMIT ' + maxArticles;
            List<List<SObject>> results = Search.query(soslQuery);
            return (results != null && !results.isEmpty())
                ? (List<Knowledge__kav>) results[0]
                : new List<Knowledge__kav>();
        }
    }

    private static String format(List<Knowledge__kav> articles) {
        List<String> blocks = new List<String>();
        Integer i = 1;
        for (Knowledge__kav a : articles) {
            String body = stripHtml(a.FAQ_Answer__c);
            if (body.length() > 1500) {
                body = body.substring(0, 1500) + '...';
            }
            String block = 'Article ' + i + ': ' + a.Title
                + '\nSummary: ' + nvl(a.Summary)
                + '\nContent: ' + body
                + '\nArticle Link: /article/' + nvl(a.UrlName);
            blocks.add(block);
            i++;
        }
        return String.join(blocks, '\n\n');
    }

    // SOSL reserved characters must be escaped so caller-supplied text can't break the query.
    @TestVisible
    private static String sanitize(String input) {
        if (String.isBlank(input)) {
            return '';
        }
        String cleaned = input.replaceAll('[?&|!{}\\[\\]()^~*:"+\\-\\\\]', ' ');
        return cleaned.replaceAll('\\s+', ' ').trim();
    }

    private static String stripHtml(String html) {
        if (String.isBlank(html)) {
            return '';
        }
        return html.replaceAll('<[^>]+>', ' ').replaceAll('&nbsp;', ' ').replaceAll('\\s+', ' ').trim();
    }

    private static String nvl(String value) {
        return value == null ? '' : value;
    }
}
