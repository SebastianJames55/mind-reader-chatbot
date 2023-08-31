-- You can run the following commands in your local mindsdb setup

-- Creating a project. This will contain the model, views and job you are about to create
CREATE PROJECT mind_reader_project;

-- Creating a model which will predict the response
CREATE MODEL mind_reader_project.gpt_model
PREDICT response
USING
engine = 'openai',
max_tokens = 300,
api_key = '<your-openai-api-key>', -- In MindsDB cloud accounts we provide a default key
model_name = 'gpt-3.5-turbo', -- You can also use 'text-davinci-003'
prompt_template = 'Reply like a friend who cares and wants to help.\
                Input message: {{text}}\
                In less than 550 characters, when there is some sign of distress in the input share healthy habits, \
                motivational quotes, inspirational real-life stories.
                Provide options to seek out in-person help if you are not able to satisfy.'; -- Prompt which will decide the style of output

-- Confirm if the model status is complete before proceeding
SELECT *
FROM mind_reader_project.models
WHERE name='gpt_model'; -- Name of the model within our project

-- Query the model to get a response
SELECT response
FROM mind_reader_project.gpt_model
WHERE text = "Not doing so great"; -- Input to the model

-- Creating yugabyteDB instance
CREATE DATABASE yugabyte_demo
WITH
    engine = 'yugabyte',
    parameters = {
        "user": "admin", -- User name
        "password": "password", -- Password associated with the user
        "host": "link", -- Link to the instance which hosts the DB
        "port": 5433,
        "database": "demo", -- Database name in instance
        "schema": "public" -- Schema name in instance
    };

-- Viewing the stored inputs
SELECT * from yugabyte_demo.chatbot_input;

-- Storing input into the table
INSERT INTO yugabyte_demo.chatbot_input (text)
VALUES ('feeling lonely');

-- Storing output generated from the model based on the input data
INSERT INTO yugabyte_demo.chatbot_output (
SELECT r.response AS text -- Response from model
FROM yugabyte_demo.chatbot_input t
JOIN mind_reader_project.gpt_model r
);

-- Viewing the responses stored in table
SELECT *
FROM yugabyte_demo.chatbot_output;

-- View that stores the input messages which haven't been replied to yet
CREATE VIEW mind_reader_project.to_reply_to (
SELECT id, text FROM yugabyte_demo.chatbot_input
WHERE id NOT IN (SELECT r.id FROM yugabyte_demo.chatbot_output AS r) -- Fetching input which hasn't been replied to
);

-- View the messages which haven't been replied to
SELECT *
FROM mind_reader_project.to_reply_to;

-- View that stores the responses (against the messages which weren't replied to) from model
CREATE VIEW mind_reader_project.to_chatbot_output (
    SELECT * FROM mind_reader_project.to_reply_to
    JOIN mind_reader_project.gpt_model
);

-- Job to automate the flow, runs every minute
CREATE JOB mind_reader_project.chatbot_job (
    -- Storing the responses from model in output table
    INSERT INTO yugabyte_demo.chatbot_output (
        SELECT
            id,
            response AS text
        FROM mind_reader_project.to_chatbot_output
    )

) EVERY MINUTE;

-- See all the jobs within the project
SELECT *
FROM mind_reader_project.jobs where name = "chatbot_job";

-- Once job is created, input message
INSERT INTO yugabyte_demo.chatbot_input (text)
VALUES ('feeling lonely');

-- Output table will be updated by the job every minute in case of new input messages
SELECT *
FROM yugabyte_demo.chatbot_output;

-- See the whole history of the jobs within the project
SELECT *
FROM mind_reader_project.jobs_history;

-- Drop the database instance from mindsdb
DROP DATABASE yugabyte_demo;

-- Drop the running job
DROP JOB mind_reader_project.chatbot_job;

-- Drop the gpt_model
DROP MODEL mind_reader_project.gpt_model;

-- Drop the to_reply_to view
DROP VIEW mind_reader_project.to_reply_to;

-- Drop the to_chatbot_output view
DROP VIEW mind_reader_project.to_chatbot_output;

-- Drop the mind_reader_project
DROP PROJECT mind_reader_project;
