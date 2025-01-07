CREATE TABLE Areas (
    Area_ID NUMBER PRIMARY KEY,
    Area_Name VARCHAR2(100),
    Population NUMBER
);

CREATE TABLE Collection_Schedules (
    Schedule_ID NUMBER PRIMARY KEY,
    Area_ID NUMBER,
    Collection_Date DATE,
    Disposal_Site_ID NUMBER,
    Status VARCHAR2(20) DEFAULT 'Scheduled',
    FOREIGN KEY (Area_ID) REFERENCES Areas(Area_ID)
);

CREATE TABLE Disposal_Sites (
    Site_ID NUMBER PRIMARY KEY,
    Site_Name VARCHAR2(100),
    Capacity NUMBER,
    Current_Utilization NUMBER DEFAULT 0
);

CREATE TABLE Collection_Log (
    Log_ID NUMBER PRIMARY KEY,
    Schedule_ID NUMBER,
    Area_ID NUMBER,
    Disposal_Site_ID NUMBER,
    Collection_Date DATE,
    Status VARCHAR2(20),
    FOREIGN KEY (Schedule_ID) REFERENCES Collection_Schedules(Schedule_ID)
);

CREATE OR REPLACE PROCEDURE Generate_Collection_Schedule IS
BEGIN
    FOR area IN (SELECT * FROM Areas) LOOP
        INSERT INTO Collection_Schedules (Schedule_ID, Area_ID, Collection_Date, Disposal_Site_ID)
        VALUES ((SELECT NVL(MAX(Schedule_ID), 0) + 1 FROM Collection_Schedules),
                area.Area_ID,
                SYSDATE + MOD(area.Area_ID, 7),
                MOD(area.Area_ID, (SELECT COUNT(*) FROM Disposal_Sites)) + 1);
    END LOOP;
    COMMIT;
END Generate_Collection_Schedule;
/

CREATE OR REPLACE FUNCTION Calculate_Disposal_Utilization(site_id IN NUMBER) RETURN NUMBER IS
    v_utilization_percentage NUMBER;
BEGIN
    SELECT (Current_Utilization / Capacity) * 100 INTO v_utilization_percentage
    FROM Disposal_Sites
    WHERE Site_ID = site_id;

    RETURN v_utilization_percentage;
END Calculate_Disposal_Utilization;
/

CREATE OR REPLACE TRIGGER Track_Missed_Collections
AFTER UPDATE OF Status ON Collection_Schedules
FOR EACH ROW
WHEN (NEW.Status = 'Missed')
BEGIN
    INSERT INTO Collection_Log (Log_ID, Schedule_ID, Area_ID, Disposal_Site_ID, Collection_Date, Status)
    VALUES ((SELECT NVL(MAX(Log_ID), 0) + 1 FROM Collection_Log),
            :NEW.Schedule_ID,
            :NEW.Area_ID,
            :NEW.Disposal_Site_ID,
            :NEW.Collection_Date,
            'Missed');

    DBMS_OUTPUT.PUT_LINE('Missed collection for Area ID: ' || :NEW.Area_ID || 
                         ' on ' || TO_CHAR(:NEW.Collection_Date, 'DD-MON-YYYY'));
END Track_Missed_Collections;
/

INSERT INTO Areas (Area_ID, Area_Name, Population) VALUES (1, 'Downtown', 50000);
INSERT INTO Areas (Area_ID, Area_Name, Population) VALUES (2, 'Suburb', 20000);
INSERT INTO Areas (Area_ID, Area_Name, Population) VALUES (3, 'Industrial Zone', 15000);

INSERT INTO Disposal_Sites (Site_ID, Site_Name, Capacity) VALUES (1, 'North Site', 100000);
INSERT INTO Disposal_Sites (Site_ID, Site_Name, Capacity) VALUES (2, 'South Site', 80000);

BEGIN
    Generate_Collection_Schedule;
END;
/

BEGIN
    DBMS_OUTPUT.PUT_LINE('Utilization of Site 1: ' || Calculate_Disposal_Utilization(1) || '%');
END;
/

UPDATE Collection_Schedules
SET Status = 'Missed'
WHERE Schedule_ID = 1;

SELECT * FROM Areas;

SELECT * FROM Collection_Schedules;

SELECT * FROM Disposal_Sites;

SELECT * FROM Collection_Log;
