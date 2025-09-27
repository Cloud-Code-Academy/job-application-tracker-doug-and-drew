trigger EventTrigger on Event (before insert, before update) {

    EventTriggerHandler handler = new EventTriggerHandler();
    handler.run();

}

