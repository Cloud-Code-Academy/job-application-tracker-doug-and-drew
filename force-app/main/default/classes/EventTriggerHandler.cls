public with sharing class EventTriggerHandler extends TriggerHandler {
    
    private List<Event> newEventsList;
    private Map<Id, Event> newEventsMap;
    private List<Event> oldEventsList;
    private Map<Id, Event> oldEventsMap;

    public EventTriggerHandler(){
        this.newEventsList = (List<Event>)Trigger.new;
        this.newEventsMap = (Map<Id, Event>)Trigger.newMap;
        this.oldEventsList = (List<Event>)Trigger.old;
        this.oldEventsMap = (Map<Id, Event>)Trigger.oldMap;
    }

    public override void beforeInsert(){ 
        EventHelper.beforeInsert(newEventsList);
    } 

    /* public override void afterInsert(){
        
    } */

    public override void beforeUpdate(){ 
        EventHelper.beforeUpdate(oldEventsMap, newEventsList);
    } 

    /* public override void afterUpdate(){ 
        
    } */

    /* public override void beforeDelete(){ 
        
        
    } */

    /* public override void afterDelete(){ 
        
        
    } */

    /* public override void afterUndelete(){ 
        
        
    } */

}