/**
 * Vireon virtual-human escalation - Resolve Case action.
 *
 * Closes the escalated case with a resolution summary once the specialist has
 * handled the issue, logging the resolution as a final CaseComment.
 */
public with sharing class VireonResolveCase {
    public class Request {
        @InvocableVariable(
            label='Case Id'
            description='Id of the case to resolve.'
            required=true
        )
        public String caseId;

        @InvocableVariable(
            label='Resolution Summary'
            description='How the issue was resolved.'
            required=true
        )
        public String resolutionSummary;

        @InvocableVariable(
            label='Author Name'
            description='Specialist display name, prefixed onto the resolution comment.'
        )
        public String authorName;
    }

    public class Result {
        @InvocableVariable(label='Case Number')
        public String caseNumber;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(
        label='Vireon: Resolve Escalation Case'
        description='Closes the escalated case with a resolution summary.'
    )
    public static List<Result> resolveCase(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(processOne(req));
        }
        return results;
    }

    private static Result processOne(Request req) {
        Result res = new Result();
        try {
            if (String.isBlank(req.caseId) || String.isBlank(req.resolutionSummary)) {
                res.success = false;
                res.message = 'A case id and resolution summary are required.';
                return res;
            }
            Id cid = (Id) req.caseId;
            String prefix = String.isBlank(req.authorName) ? '' : '[' + req.authorName + '] ';

            insert new CaseComment(
                ParentId = cid,
                CommentBody = prefix + 'Resolution: ' + req.resolutionSummary,
                IsPublished = true
            );

            update new Case(Id = cid, Status = 'Closed');

            Case closed = [SELECT CaseNumber FROM Case WHERE Id = :cid LIMIT 1];
            res.caseNumber = closed.CaseNumber;
            res.success = true;
            res.message = 'Case ' + closed.CaseNumber + ' resolved and closed.';
        } catch (Exception e) {
            res.success = false;
            res.message = 'Could not resolve case: ' + e.getMessage();
        }
        return res;
    }
}
