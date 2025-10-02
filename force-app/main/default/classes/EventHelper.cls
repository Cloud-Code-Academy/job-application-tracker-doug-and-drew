public with sharing class EventHelper {
    
    // BEFORE_INSERT

    public static void beforeInsert(List<Event> newEventsList) {
        if (newEventsList == null || newEventsList.isEmpty()) {
            return;
        }
        processValidationAndConflicts(null, newEventsList, /*isUpdate*/false);

    }

    // AFTER INSERT

    //BEFORE_UPDATE

    public static void beforeUpdate(Map<Id, Event> oldEventsMap, List<Event> newEventsList) {
        if (newEventsList == null || newEventsList.isEmpty()) {
            return;
        }
        processValidationAndConflicts(oldEventsMap, newEventsList, /*isUpdate*/true);

    }

    //AFTER_UPDATE

    //BEFORE_DELETE

    //AFTER_DELETE

    //AFTER_UNDELETE

    //=================================
    // MAIN FUNCTIONALITY
    //=================================

    public static void processValidationAndConflicts (
        Map<Id, Event> oldEventsMap,
        List<Event> newEventsList,
        Boolean isUpdate) {
        // Extra null guard for safety/scalability
        if (newEventsList == null || newEventsList.isEmpty()) {
            return;
        }

        // Check context - Insert or Update.   
        // Add events to a Set for Validation Checks.  If it is update context, check new context against old 
        // for scheduling related changes
        Set<Id> eventsNeedingChecks = new Set<Id>();
        for (Event e : newEventsList) {
            if (!isUpdate || hasScheduleFieldsChanged(oldEventsMap.get(e.Id), e)) {
                eventsNeedingChecks.add(e.Id);
            }
        }
        if (isUpdate && eventsNeedingChecks.isEmpty()) {
            return; // nothing relevant changed
        }

        // Loop through to get the OwnerIds, and set the earliest start time and latest end time from all
        // the new events in the list, to narrow query for upcoming existing events.  
        Set<Id> ownerIds = new Set<Id>();
        Set<Id> currentBatchIds = new Set<Id>(); // will only be populated in update context as Events will already have an Id
        DateTime minStart, maxEnd;

        // Track which Events passed validation to avoid checking the ones with errors again
        Set<Id> validEvents = new Set<Id>();

        // bucket new events by owner for new-vs-new overlap checks
        Map<Id, List<Event>> newByOwner = new Map<Id, List<Event>>();

        for (Event e : newEventsList) {
            // Only process Events that require checks (on update)
            if (isUpdate && !eventsNeedingChecks.contains(e.Id)) {
                continue;
            }

            // Validate user inputs and throw errors if needed
            if (!validateEventInputs(e)) {
                // if it returns false, the event has errors and can be skipped from further checks
                continue;
            }

            // Track valid events and add Ids to Set
            if (e.Id != null) {
                validEvents.add(e.Id); // only meaningful on update; insert Ids are null
            }
            
            // Collect Owner and Id (Id only present on update)
            if (e.OwnerId != null) {
                ownerIds.add(e.OwnerId);

                // Build the per-owner bucket of "new" events for new-vs-new checks
                List<Event> bucket = newByOwner.get(e.OwnerId);
                if (bucket == null) {
                    bucket = new List<Event>();
                    newByOwner.put(e.OwnerId, bucket);
                }
                bucket.add(e);
            }
            if (e.Id != null) {
                currentBatchIds.add(e.Id); // non New Events
            }

            // build Datetime list to determine the timeframe(start and finish) to narrow the query of existing events for overlap
            List<Datetime> window = eventWindow(e);
            if (window == null){
                continue; // safety
            }
            // Sets the earliest start and end time for the search window
            Datetime s = window[0], f = window[1];
            if (minStart == null || s < minStart) {
                minStart = s;
            }
            if (maxEnd == null || f > maxEnd) {
                maxEnd = f;
            }
        }

        // If nothing valid, no owners, or timeframe is incomplete, bail out
        if (newByOwner.isEmpty() || ownerIds.isEmpty() || minStart == null || maxEnd == null) {
            return;
        }
        // COMPARING NEW EVENTS AGAINST EXISTING EVENTS PER OWNER
        // Query for existing overlapping events excluding the events from the current transaction/batch that are about to be saved 
        // on update so we don't compare an event with itself
        Map<Id, List<Event>> ownerToExisting = new Map<Id, List<Event>>();
        List<Event> existing;
        // update context
        if (isUpdate && !currentBatchIds.isEmpty()) {
            existing = [
                SELECT Id, OwnerId, StartDateTime, EndDateTime, IsAllDayEvent, ActivityDate
                FROM Event
                WHERE OwnerId IN : ownerIds
                AND EndDateTime > : minStart
                AND StartDateTime < : maxEnd
                AND Id NOT IN :currentBatchIds
                ORDER BY StartDateTime ASC
            ];
        } else {
            // insert context
            existing = [
            SELECT Id, OwnerId, StartDateTime, EndDateTime, IsAllDayEvent, ActivityDate
            FROM Event
            WHERE OwnerId IN : ownerIds
            AND EndDateTime > : minStart
            AND StartDateTime < : maxEnd
            ORDER BY StartDateTime ASC
            ];
        } 
        // Store as a map of Owner Ids to List of Existing Events
        for (Event e : existing) {
            List<Event> eventBucket = ownerToExisting.get(e.OwnerId);
            if (eventBucket == null) {
                eventBucket = new List<Event>();
                ownerToExisting.put(e.OwnerId, eventBucket);
            }
            eventBucket.add(e);
        }

        // EVENT OVERLAP CHECKS
        // For each new Event overlap check with ownerToExisting
        for (Event ne : newEventsList) {
            if (isUpdate && ne.Id != null && !validEvents.contains(ne.Id)) {
                continue;  // Event not valid or not relevant on update
            }
            if (ne.OwnerId == null){
                continue;
            }

            // Do not enforce overlap if event is AllDayEvent
            if (ne.IsAllDayEvent) {
                continue;
            }

            // ----------- new vs existing ----------------
            List<Event> relatedExistingEvents = ownerToExisting.get(ne.OwnerId);
            if (relatedExistingEvents != null && !relatedExistingEvents.isEmpty()) {
                // Build time frame for new events, and assign start and finish variables
                List<Datetime> newWindow = eventWindow(ne);
                if (newWindow != null) {
                    Datetime ns = newWindow[0], nf = newWindow[1];
                    // Build time frame for all existing events, and assign start and finish variables
                    for (Event ex : relatedExistingEvents) {
                        if (ex.IsAllDayEvent) {
                            continue;
                        }
                        List<Datetime> existingWindow = eventWindow(ex);
                        if (existingWindow == null) {
                            continue;
                        }
                        Datetime es = existingWindow[0], ef = existingWindow[1];
                        // compare time frame for each task, against the time frame of all existing task per owner
                        // the new task overlaps with existing tasks, throw error
                        if (overlaps(ns, nf, es, ef)) {
                            ne.StartDateTime.addError('This event overlaps with an existing event for this owner.');
                            break; // block save
                        }
                    }
                }
            }
        }
        // ----------- new vs new ------------
        // check overlaps of all new events per owner, within the same transaction
        for (ID ownerId : newByOwner.keySet()) {
            List<Event> eventBatch = newByOwner.get(ownerId);
            if (eventBatch == null || eventBatch.size() <= 1) {
                continue;
            }
            // For each event in the list we will loop through every other event in the same list
            for (Integer i = 0; i < eventBatch.size(); i++) {
                Event a = eventBatch[i];
                // Skip if the first event is all-day
                if (a.IsAllDayEvent) {
                    continue;
                }
                List<Datetime> aw = eventWindow(a);
                if (aw == null){
                    continue;
                }
                Datetime aStart = aw[0];
                Datetime aEnd = aw[1];

                // Skip comparisons against all-day
                for (Integer j = i + 1; j < eventBatch.size(); j++) {
                    Event b = eventBatch[j];
                    if (b.IsAllDayEvent) {
                        continue;
                    }
                    List<Datetime> bw = eventWindow(b);
                    if (bw == null){
                        continue;
                    }
                    Datetime bStart = bw[0]; 
                    Datetime bEnd = bw[1];

                    if (overlaps(aStart, aEnd, bStart, bEnd)) {
                        a.StartDateTime.addError('This event overlaps another event you are saving right now.');
                        b.StartDateTime.addError('This event overlaps another event you are saving right now.');
                    }
                }

            }           
            
        }

    }  
    //==============================
    // HELPER METHODS:
    //==============================

    // VALIDATION(user-facing)
    // Add errors to fields which require values or whose values are invalid
    // returns true if inputs are valid, false if any error was thrown
    private static Boolean validateEventInputs(Event e) {
        if (e == null) {
            return false;
        }

        // Determine interval window
        Datetime s, f;
        // Check for All-day Events
        if (e.IsAllDayEvent == true) {
            if (e.ActivityDate == null) {
                e.StartDateTime.addError('For all-day events, Start and End must have a value(The whole day is reserved).');
                return false;
            }
            s = Datetime.newInstance(e.ActivityDate, Time.newInstance(0, 0, 0, 0));
            f = s.addDays(1);
        } else {
            // Anything that is not an All-day Event
            s = e.StartDateTime;
            f = e.EndDateTime;
            if (s == null) {
                e.StartDateTime.addError('Start time is required');
                return false;
            }
            if (f == null) {
                e.EndDateTime.addError('End time is required');
                return false;
            }
        }

        // End time must be after Start time
        // NOTE: Salesforce already enforces this rule (platform validation).
        // We skip this here to avoid duplicate/conflicting errors.

        // Weekend Rule
        if (isWeekend(s.date())) {
            e.StartDateTime.addError('Interviews cannot be scheduled on weekends.');
            return false;
        }
        return true;        
    }

    // WEEKEND CHECK using modulo to determine if Saturday(6) or Sunday(0)
    @TestVisible
    private static Boolean isWeekend(Date d) {
        if (d == null) {
            return false;
        }
        Date knownSunday = Date.newInstance(1900, 1, 7); // a known Sunday
        // determines the number of days between the known Sunday and the current date
        // divides the result by 7 and returns the remainder using the mod method.
        Integer dayOfWeek = Math.mod(knownSunday.daysBetween(d), 7); 
        // if the remainder is 0, it is a Sunday, and if it 6, it is a Saturday.
        return dayOfWeek == 0 || dayOfWeek == 6;
    }

    // OVERLAP - returns true if two Events overlap one another
    // back-to-back Events are allowed:
    // overlap: aStart < bEnd AND aEnd > bStart
    private static Boolean overlaps(Datetime aStart, Datetime aEnd,
                                    Datetime bStart, Datetime bEnd) {
        // if the method returns true, there is overlap between the two events
        return (aStart != null && aEnd != null && bStart != null && bEnd != null) 
            && (aStart < bEnd) && (aEnd > bStart);
    }

    // For BEFORE UPDATE, returns true if any scheduling-relevant field changed
    private static Boolean hasScheduleFieldsChanged(Event oldE, Event newE) {
        if (oldE == null || newE == null) {return true;}
        if (oldE.OwnerId != newE.OwnerId) {return true;}
        if (oldE.IsAllDayEvent != newE.IsAllDayEvent) {return true;}
        if (oldE.ActivityDate != newE.ActivityDate) {return true;}
        if (oldE.StartDateTime != newE.StartDateTime) {return true;}
        if (oldE.EndDateTime != newE.EndDateTime) {return true;}
        return false;
    }

    // Convert an Event to a start time and end time window
    private static List<Datetime> eventWindow(Event e) {
        if (e == null) {
            return null;
        }
        Datetime s = e.IsAllDayEvent 
            ? Datetime.newInstance(e.ActivityDate, Time.newInstance(0,0,0,0)) 
            : e.StartDateTime;
        Datetime f = null;
        if (e.IsAllDayEvent) {
            if (s != null) {
                f = s.addDays(1);
            } 
        } else {
            f = e.EndDateTime;
        }
        if (s == null || f == null){
            return null;
        }
        return new List<Datetime>{s, f};
    }

}