/**
 * Vireon virtual-human escalation - Add Case Comment action.
 *
 * Logs a CaseComment on the escalated case so the conversation looks like a
 * human specialist working the case inside Service Cloud. Each comment is
 * prefixed with the specialist's name.
 */
public with sharing class VireonAddCaseComment {
    public class Request {
        @InvocableVariable(
            label='Case Id'
            description='Id of the case to comment on.'
            required=true
        )
        public String caseId;

        @InvocableVariable(
            label='Comment Body'
            description='What the specialist did or advised in this step.'
            required=true
        )
        public String commentBody;

        @InvocableVariable(
            label='Author Name'
            description='Specialist display name, prefixed onto the comment.'
        )
        public String authorName;
    }

    public class Result {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(
        label='Vireon: Add Case Comment'
        description='Adds a specialist-authored comment to the escalated case.'
    )
    public static List<Result> addComment(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(processOne(req));
        }
        return results;
    }

    private static Result processOne(Request req) {
        Result res = new Result();
        try {
            if (String.isBlank(req.caseId) || String.isBlank(req.commentBody)) {
                res.success = false;
                res.message = 'A case id and comment body are required.';
                return res;
            }
            String prefix = String.isBlank(req.authorName) ? '' : '[' + req.authorName + '] ';
            insert new CaseComment(
                ParentId = (Id) req.caseId,
                CommentBody = prefix + req.commentBody,
                IsPublished = true
            );
            res.success = true;
            res.message = 'Comment added.';
        } catch (Exception e) {
            res.success = false;
            res.message = 'Could not add comment: ' + e.getMessage();
        }
        return res;
    }
}
