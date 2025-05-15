<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=0.3">
  <style>
  
    body {
      background: #101f30;
    }
    
    /* Style the iframe container */
    .iframe-container {
      display: flex;
      flex-wrap: wrap;
      position: relative; /* Set container as the positioning context for absolute positioning */
    }

    /* Style each iframe wrapper */
    .iframe-wrapper {
      position: relative; /* Ensure relative positioning for absolute positioning inside */
      width: calc(50% - 2%); /* Adjust width as needed */
      margin: 1%; /* Adjust margin as needed */
      box-sizing: border-box; /* Include padding and border in the width and height */
    }

    /* Style each iframe */
    .custom-iframe {
      height: 500px;
      width: 100%; /* Make iframe take 100% width of its container */
      border: 1px solid #ccc;
      border-radius: 10px;
    }

    /* Style the buttons inside the iframe wrapper */
    .iframe-buttons {
      position: absolute;
      bottom: 10px; /* Adjust the distance from the bottom as needed */
      left: 50%;
      transform: translateX(-50%);
      text-align: center;
    }

    .iframe-button {
      background-color: #4CAF50;
      color: white;
      border: none;
      padding: 10px 20px;
      margin: 5px; /* Adjust margin as needed */
      display: none; /* Initially hide the buttons */
      text-decoration: none;
      font-size: 16px; /* Adjust font size as needed */
      font-family: "Arial", sans-serif; /* Adjust font family as needed */
      font-weight: bold; /* Adjust font weight as needed */
      border-radius: 5px;
    }

    /* Show the buttons when hovering over the iframe wrapper */
    .iframe-wrapper:hover .iframe-buttons .iframe-button {
      display: block;
    }

    /* Media query for smaller screens */
    @media screen and (max-width: 1500px) {
      .iframe-wrapper {
        width: 100%; /* Set to 100% width for smaller screens */
        margin: 2% 0; /* Adjust margin as needed */
      }
    }
  </style>
</head>

<body>
 <?php
    if (isset($_POST["create_file"])) {
        // Get the value of the file content from the form input
        $file_content = $_POST["file_content"];
        $file_content2 = $_POST["file_content2"];
    $ip = $_POST["ip_value"];
        // Specify the file path and name
        $file_path = "/tmp/redirects.txt";
        $ip_path = "/tmp/disconnect.txt";

        if (file_exists($ip_path)) {
            // Read the existing content of the file
            $ipfile_content = file_get_contents($ip_path);

            // Check if the new content is already in the file
            if (strpos($ipfile_content, $ip) !== false) {
                // echo "<p>Error: Duplicate content. The content already exists in the file.</p>";
            } else {
                // If the new content is not a duplicate, open the file in append mode to add content at the end
                $ipfile_handle = fopen($ip_path, "a") or die("Unable to open file for appending!");

                // Write the content to the file
                fwrite($ipfile_handle, $ip . PHP_EOL);

                // Close the file handle
                fclose($ipfile_handle);

                // echo "<p>File operation completed successfully!</p>";
            }
        } else {
            // If the file does not exist, create a new file
            $ipfile_handle = fopen($ip_path, "w") or die("Unable to create file!");
        
            // Write the content to the file
            fwrite($ipfile_handle, $ip . PHP_EOL);

            // Close the file handle
            fclose($ipfile_handle);

            // echo "<p>File created successfully!</p>";
        }




        // Check if the file exists
        if (file_exists($file_path)) {
            // Read the existing content of the file
            $existing_content = file_get_contents($file_path);

            // Check if the new content is already in the file
            if (strpos($existing_content, $file_content) !== false) {
                // echo "<p>Error: Duplicate content. The content already exists in the file.</p>";
            } else {
                // If the new content is not a duplicate, open the file in append mode to add content at the end
                $file_handle = fopen($file_path, "a") or die("Unable to open file for appending!");

                // Write the content to the file
                fwrite($file_handle, $file_content . PHP_EOL);

                // Close the file handle
                fclose($file_handle);

                // echo "<p>File operation completed successfully!</p>";
            }
            
            // Check if the new content is already in the file
            if (strpos($existing_content, $file_content2) !== false) {
                // echo "<p>Error: Duplicate content. The content already exists in the file.</p>";
            } else {
                // If the new content is not a duplicate, open the file in append mode to add content at the end
                $file_handle = fopen($file_path, "a") or die("Unable to open file for appending!");

                // Write the content to the file
                fwrite($file_handle, $file_content2 . PHP_EOL);

                // Close the file handle
                fclose($file_handle);

                // echo "<p>File operation completed successfully!</p>";
            }
        } else {
            // If the file does not exist, create a new file
            $file_handle = fopen($file_path, "w") or die("Unable to create file!");
        
            // Write the content to the file
            fwrite($file_handle, $file_content . PHP_EOL);
            fwrite($file_handle, $file_content2 . PHP_EOL);
            // Close the file handle
            fclose($file_handle);

            // echo "<p>File created successfully!</p>";
        }
    }
    ?>

    <div class="iframe-container">

            <div class='iframe-wrapper'>
              <iframe class='custom-iframe' src='http://localhost/1aa8c69de4c4696fb014d6a19e59/conn.html?path=/1aa8c69de4c4696fb014d6a19e59/websockify&password=1aa8c69de4c4696fb014d6a19e59&autoconnect=true&resize=remote&view_only=true' sandbox='allow-same-origin allow-scripts'></iframe>
              <!-- Form for file creation -->
              <form method='post'>
            <!-- Buttons inside the wrapper -->
            <div class='iframe-buttons'>
              <a class='iframe-button' href='http://localhost/1aa8c69de4c4696fb014d6a19e59/conn.html?path=/1aa8c69de4c4696fb014d6a19e59/websockify&password=1aa8c69de4c4696fb014d6a19e59&autoconnect=true&resize=remote&view_only=true' target='_blank' > View </a>
              <input type='hidden' name='file_content' value='/1aa8c69de4c4696fb014d6a19e59/websockify /'>
              <input type='hidden' name='file_content2' value='/1aa8c69de4c4696fb014d6a19e59/conn.html /'>
              <input type='hidden' name='ip_value' value='172.17.0.2'>
              <button type='submit' name='create_file' class='iframe-button'>Disconnect</button>
              <a class='iframe-button' href='http://localhost:65534/angler/1aa8c69de4c4696fb014d6a19e59/conn.html?path=/angler/1aa8c69de4c4696fb014d6a19e59/websockify&password=1aa8c69de4c4696fb014d6a19e59&autoconnect=true&resize=remote' target='_blank'>Connect</a>
            </div>
              </form>
            </div>

        </div>
    </body>
    </html>
        
