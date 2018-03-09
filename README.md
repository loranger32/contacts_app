# Training Contact App

This is a training project for the [Launch School](https://www.launchschool.com)
170 course.

Features :

- user management (signup, login, logout) ;
- password encryption with BCrypt ;
- admin privileges ;
- contact list available to signed in users only ;
- a contact *can* have the following attributes :
  - first name ;
  - last name ;
  - adress ;
  - phone number ;
  - mail adress ;
  - country ;
  - date of birth ;
  - category(ies) ;
- a contact *must* have a first name and last name ;
- contacts can be linked to categories ;
- a category's members can be shown separately ;
- when a category is deleted, it is also removed form all the contacts which
  belongs to it

Because the 170 course is all about back-end and Sinatra, there is very little
attention paid to style.
