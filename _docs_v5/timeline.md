---
layout: docs
title: Timeline 
toc: true
---

## Introduction

Timeline allows for the simple execution of commands and scripts. This uses the microservice operator in cosmos to run a multi-threaded application to listen for updates to the timelie schedule and execute on about a seconds accuracy.

![Timeline](/img/v5/timeline/timeline.png)

## Timeline Menus

### View Menu Items

<!-- Image sized to match up with bullets -->

<img src="/img/v5/timeline/view_menu.png"
     alt="File Menu"
     style="float: left; margin-right: 50px; height: 6em;" />

- Signal the web page to refresh
- Set the activity view to view in a list (better for shorter tasks)
- Set the activity view to view in a calendar (better for longer tasks)

### Time Menu Items

<!-- Image sized to match up with bullets -->

<img src="/img/v5/timeline/time_menu.png"
     alt="Mode Menu"
     style="float: left; margin-right: 50px; height: 4em;" />

- Set time to display in local time
- Set time to display in UTC time

### Adding Timelines

![Timeline Create Icon](/img/v5/timeline/timeline_create_icon.png)

Adding a timeline to Cosmos.

 - Each timeline consists on several threads so be careful of your compute resources you have as you can overhelm cosmos with lots of these.
 - Also note can not have over lapping activities on a single timeline.

### Timeline List View

View activities on a timeline or multiple timelines in a data table view.

![Timeline List](/img/v5/timeline/timeline_list.png)

### Timeline Calender View

View activities on a timeline or multiple timelines in a data table view.

![Timeline Calender](/img/v5/timeline/timeline_cal.png)

### Adding Activities

![Activity Create Icon](/img/v5/timeline/activity_create_icon.png)

Once a timeline is selected a user can schedule an activity. Currently all activities must be scheduled at least 10 seconds in the future. Currently as of writting this a user can schedule a command or a script but this could be expanded upon later. When you open the create activity menu, you should have the options of type in a drop down in the top right and an input form to input the activity. This form has some error feedback that will disable the submit or ok button. You can also select if you want to input the activity based on UTC or local time.

![Error With Create Activity](/img/v5/timeline/error_create_activity.png)

![Create Activity Complete](/img/v5/timeline/create_activity.png)

### Updating Activity

Once a timeline is selected a user can select an activity. Currently all activities must be scheduled at least 10 seconds in the future. An activity can be updated if it is not fulfilled. Note an update is a "hard" command and can cause multiple api calls to make sure the scheduled is displayed and processed correctly.

![Update Activity](/img/v5/timeline/update_activity.png)

### Multi-Timeline Selection

You can view more then on timeline at a time, with the check icon at the top of the timeline list. This should allow you to compare timelines and view activities from both.

- List view

![Multi-Timeline List](/img/v5/timeline/multi_timelines_list.png)

- Calender view

![Multi-Timeline Calender](/img/v5/timeline/multi_timelines_cal.png)

### Timeline lifecycle

When a user creates a timeline, the cosmos operator see a new microservice has been created. This signals the operator to start a new microservice, the timeline microservice. The timeline microservice is the main thread of execution for the timeline. This starts a scheduler manager thread. The scheduler manger thread contains a thread pool that hosts more then one thread to run the activity. The scheduler manger will evaluate the schedule and based on the start time of the activity it will add the activity to the queue.

The main thread will block on the web socket to listen to request changes to the timeline, these could be adding, removing, or updating acitivities. This will make the changes to the schedule if they are within the hour but not out side of that as we don't want to hold everything in memory. When the web socket gets an update it has an action lookup table that based on the change takes different actions that could include removing the block and updating the schedule from the database to ensure the schedule and the database are always in synk.

The schedule thread is check every second to make sure if a task can be run. If the start time is equal or less then the last 15 seconds it will then check the previously queued jobs list in the schedule. If the activity has not been queued and is not fulfilled. If the activity passes these check then a queued event is added to the activity but the activity is not saved to the database. The activity will be added to the queue to be worked by the worker threads. (TODO) This could be improved upon as a was to wake the thread when a change to the schedule happens or when a job needs to run.

The workers are plain and simple, they block on the queue until an activity is placed on the queue. Once a job is pulled from the queue they check the type and run the activity. The thread will mark the activity fulfillment true and update the database record with the complete. If the worker gets an error while trying to run the task the activity will NOT be fulfilled and record the error in the database.

![Timeline Lifecycle](/img/v5/timeline/timeline_lifecycle.png)