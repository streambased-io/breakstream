#! /bin/bash

GREEN='\033[0;32m'
NC='\033[0m' # No Color

PARAGRAPH=$1

if [ "$PARAGRAPH" == "header" ]
then
  echo "______                _        _                            "
  echo "| ___ \              | |      | |                           "
  echo "| |_/ /_ __ ___  __ _| | _____| |_ _ __ ___  __ _ _ __ ___  "
  echo "| ___ \ '__/ _ \/ _\` | |/ / __| __| '__/ _ \/ _\` | '_ \` _ \ "
  echo "| |_/ / | |  __/ (_| |   <\__ \ |_| | |  __/ (_| | | | | | |"
  echo "\____/|_|  \___|\__,_|_|\_\___/\__|_|  \___|\__,_|_| |_| |_|"
  echo "                                                            "
  echo "                                                            "
  echo "Welcome to BreakStream, the interactive Streambased testing environment..."
  echo "                                                            "
  echo "                                                            "
  echo ""
fi

if [ "$PARAGRAPH" = "architecture" ]
then
  echo "Streambased combines real-time data in Kafka with lake data in Iceberg to provide a unified view of your data."
  echo ""
  echo "┌────────────────────────────────────────────────────────────────────────────┐"
  echo "│                              APPLICATIONS                                  │"
  echo "│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │"
  echo "│  │  REST / UI   │  │ Spark/Trino  │  │ Kafka Apps   │  │ Data Science │    │"
  echo "│  │ (Slipstream) │  │ (Iceberg)    │  │ (Consumers)  │  │ (Notebooks)  │    │"
  echo "│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │"
  echo "└─────────┼─────────────────┼─────────────────┼─────────────────┼────────────┘"
  echo "          │                 │                 │                 │"
  echo "          ▼                 ▼                 ▼                 ▼"
  echo "┌─────────────────────────────────────────────────────────────────────────────┐"
  echo "│                                                                             │"
  echo "│                          STREAMBASED LAYER                                  │"
  echo "│                                                                             │"
  echo "└─────────────────────────────────────────────────────────────────────────────┘"
  echo "                              │"
  echo "        ┌─────────────────────┴─────────────────────┐"
  echo "        │                                           │"
  echo "        ▼                                           ▼"
  echo "┌───────────────────────────────┐   ┌───────────────────────────────┐"
  echo "│           HOTSET              │   │          COLDSET              │"
  echo "│                               │   │                               │"
  echo "│  ┌─────────────────────────┐  │   │  ┌─────────────────────────┐  │"
  echo "│  │        Kafka            │  │   │  │        Iceberg          │  │"
  echo "│  │                         │  │   │  │                         │  │"
  echo "│  └─────────────────────────┘  │   │  └─────────────────────────┘  │"
  echo "│                               │   │                               │"
  echo "└───────────────────────────────┘   └───────────────────────────────┘"
  echo ""
fi

if [ "$PARAGRAPH" = "deep_dive" ]
then
  echo "Let's take a closer look at the Streambased Layer"
  echo ""
  echo "┌───────────────────────────────────────────────────────────────────┐"
  echo "│                         STREAMBASED LAYER                         │"
  echo "│                                                                   │"
  echo "│  ┌────────────────────────────┐   ┌────────────────────────────┐  │"
  echo "│  │   Streambased I.S.K.       │   │     Streambased K.S.I.     │  │"
  echo "│  │ Iceberg Service for Kafka  │   │ Kafka Service for Iceberg  │  │"
  echo "│  │                            │   │                            │  │"
  echo "│  └────────────────────────────┘   └────────────────────────────┘  │"
  echo "│                                                                   │"
  echo "└───────────────────────────────────────────────────────────────────┘"
  echo ""
  echo ""
  echo "* Streambased I.S.K. takes pre-existing Iceberg data (the cold set ) and combines"
  echo "  it with real-time data in Kafka (the hot set) to provide a unified view of your"
  echo "  data in Iceberg format."
  echo ""
  echo "* Streambased K.S.I. takes the same hot and cold set and provides it in Kafka format."
  echo ""
  echo ""
  echo ""
fi



if [ "$PARAGRAPH" = "environment" ]
then
  echo "In this environment, we will set up the typical components of a modern data architecture:"
  echo ""
  echo " * Kafka - real-time data"
  echo " * Schema Registry - governance"
  echo " * Iceberg - long term data storage"
  echo " * Spark - an industry standard data processor"
  echo ""
  echo "In addition we will deploy Streambased components:"
  echo ""
  echo " * I.S.K. - a service to surface Kafka data in Iceberg format"
  echo " * K.S.I. - a service that surfaces Iceberg data in Kafka format"
  echo ""
fi

if [ "$PARAGRAPH" = "containers" ]
then
  echo "Streambased is deployed as a set of horizontally scalable containers. In this demo environment we "
  echo "will deploy a single instance of each service, but in production you would typically deploy      "
  echo "multiple instances behind a load balancer for high availability and scalability."
  echo ""
  echo " * directstream is the I.S.K. service"
  echo " * ksi is the K.S.I. service"
  echo ""
fi

if [ "$PARAGRAPH" = "setup_intro" ]
then
  echo "First let's get set up, to populate our demo environment we will:"
  echo ""
  echo " 1. Generate a sample dataset into Kafka"
  echo " 2. Use I.S.K. to move this initial population from Kafka to Iceberg (hotset to coldset)"
  echo " 3. Start continuous data generation into Kafka"
  echo ""
  echo ""
  echo " _          _       _____       _ "
  echo "| |        | |     |  __ \     | |"
  echo "| |     ___| |_ ___| |  \/ ___ | |"
  echo "| |    / _ \ __/ __| | __ / _ \| |"
  echo "| |___|  __/ |_\__ \ |_\ \ (_) |_|"
  echo "\_____/\___|\__|___/\____/\___/(_)"
  echo "                                  "
  echo ""
fi

if [ "$PARAGRAPH" = "data_to_kafka" ]
then
  echo "Step 1: Loading an initial population into Kafka"
  echo ""
  echo "______      _              __     _   __       __ _         "
  echo "|  _  \    | |             \ \   | | / /      / _| |        "
  echo "| | | |__ _| |_ __ _   _____\ \  | |/ /  __ _| |_| | ____ _ "
  echo "| | | / _\` | __/ _\` | |______> > |    \ / _\` |  _| |/ / _\` |"
  echo "| |/ / (_| | || (_| |       / /  | |\  \ (_| | | |   < (_| |"
  echo "|___/ \__,_|\__\__,_|      /_/   \_| \_/\__,_|_| |_|\_\__,_|"
  echo "                                                            "
  echo ""
fi

if [ "$PARAGRAPH" = "kafka_to_iceberg" ]
then
  echo "Step 2: Using Spark and Streambased to move the initial population from Kafka to Iceberg"
  echo ""
  echo " _   __       __ _               __     _____         _                    "
  echo "| | / /      / _| |              \ \   |_   _|       | |                   "
  echo "| |/ /  __ _| |_| | ____ _   _____\ \    | |  ___ ___| |__   ___ _ __ __ _ "
  echo "|    \ / _\` |  _| |/ / _\` | |______> >   | | / __/ _ \ '_ \ / _ \ '__/ _\` |"
  echo "| |\  \ (_| | | |   < (_| |       / /   _| || (_|  __/ |_) |  __/ | | (_| |"
  echo "\_| \_/\__,_|_| |_|\_\__,_|      /_/    \___/\___\___|_.__/ \___|_|  \__, |"
  echo "                                                                      __/ |"
  echo "                                                                     |___/ "
  echo ""
fi

if [ "$PARAGRAPH" = "hotset_to_coldset" ]
then
  echo "So far we have assembled a dataset in Kafka (the hotset)."
  echo "The Iceberg environment (the coldset) is empty."
  echo ""
  echo "To prepare the demo environment we need to:"
  echo "  1. Copy the Kafka data to Iceberg to populate the coldset"
  echo "  2. Delete the hotset data from Kafka"
  echo ""
  echo "All of the steps are performed using Spark and Stremabased I.S.K. (we will revisit this later)."
  echo "You can see the scripts executed here:"
  echo "  ./datasets/demo/scala"
  echo ""
  echo ""
fi

if [ "$PARAGRAPH" = "post_setup_complete" ]
then
  echo ""
  echo " _____      _                 _____                       _      _       "
  echo "/  ___|    | |               /  __ \                     | |    | |      "
  echo "\ \`--.  ___| |_ _   _ _ __   | /  \/ ___  _ __ ___  _ __ | | ___| |_ ___ "
  echo " \`--. \/ _ \ __| | | | '_ \  | |    / _ \| '_ \` _ \| '_ \| |/ _ \ __/ _ \ "
  echo "/\__/ /  __/ |_| |_| | |_) | | \__/\ (_) | | | | | | |_) | |  __/ ||  __/"
  echo "\____/ \___|\__|\__,_| .__/   \____/\___/|_| |_| |_| .__/|_|\___|\__\___|"
  echo "                     | |                           | |                   "
  echo "                     |_|                           |_|                   "
fi

if [ "$PARAGRAPH" = "new_data" ]
then
  echo "Step 3: Starting continuous background data generation into Kafka"
  echo ""
  echo " _   _                ______      _              __     _   __       __ _         "
  echo "| \ | |               |  _  \    | |             \ \   | | / /      / _| |        "
  echo "|  \| | _____      __ | | | |__ _| |_ __ _   _____\ \  | |/ /  __ _| |_| | ____ _ "
  echo "| . \` |/ _ \ \ /\ / / | | | / _\` | __/ _\` | |______> > |    \ / _\` |  _| |/ / _\` |"
  echo "| |\  |  __/\ V  V /  | |/ / (_| | || (_| |       / /  | |\  \ (_| | | |   < (_| |"
  echo "\_| \_/\___| \_/\_/   |___/ \__,_|\__\__,_|      /_/   \_| \_/\__,_|_| |_|\_\__,_|"
  echo ""
fi

if [ "$PARAGRAPH" = "finish" ]
then
  echo " _____                  _____      __   __          "
  echo "|  _  |                |_   _|     \ \ / /          "
  echo "| | | |_   _____ _ __    | | ___    \ V /___  _   _ "
  echo "| | | \ \ / / _ \ '__|   | |/ _ \    \ // _ \| | | |"
  echo "\ \_/ /\ V /  __/ |      | | (_) |   | | (_) | |_| |"
  echo " \___/  \_/ \___|_|      \_/\___/    \_/\___/ \__,_|"
  echo "                                                    "
  echo ""
  echo "Demo spec detected, preserving environment for inspection. Run ./bin/stop.sh to stop the environment."
  echo ""
  echo "Here's a couple of things to try:"
  echo ""
  echo " 1. Launch spark-shell and explore the Iceberg tables directly"
  echo "      cd environment"
  echo "      docker compose exec -it spark-iceberg spark-shell"
  echo " 2. Review example Kafka client code in ./tests/demo_core/*.scala"
  echo ""
fi

if [ "$PARAGRAPH" = "test_intro" ]
then
  echo -e ""
  echo -e "${GREEN}"
  echo "In this simulated environment we will perform the following steps:"
  echo ""
  echo " 1. Use Spark to query a unified dataset composed of Kafka and Iceberg in Iceberg format using I.S.K."
  echo " 2. Use Spark to move a hotset of data in Kafka to a coldset in Iceberg"
  echo " 3. Run a sample application that consumes a dataset composed of Kafka and Iceberg in Kafka format using K.S.I."
  echo ""
  echo ""
  echo " _          _       _____       _ "
  echo "| |        | |     |  __ \     | |"
  echo "| |     ___| |_ ___| |  \/ ___ | |"
  echo "| |    / _ \ __/ __| | __ / _ \| |"
  echo "| |___|  __/ |_\__ \ |_\ \ (_) |_|"
  echo "\_____/\___|\__|___/\____/\___/(_)"
  echo "                                  "
  echo -e "${NC}"
  echo ""
fi

if [ "$PARAGRAPH" = "test_1_header" ]
then
  echo ""
  echo -e ""
  echo -e "${GREEN}"
  echo "Demo Part 1:"
  echo " _____           _                                      _   "
  echo "|  ___|         (_)                                    | |  "
  echo "| |__ _ ____   ___ _ __ ___  _ __  _ __ ___   ___ _ __ | |_ "
  echo "|  __| '_ \ \ / / | '__/ _ \| '_ \| '_ \` _ \ / _ \ '_ \| __|"
  echo "| |__| | | \ V /| | | | (_) | | | | | | | | |  __/ | | | |_ "
  echo "\____/_| |_|\_/ |_|_|  \___/|_| |_|_| |_| |_|\___|_| |_|\__|"
  echo "                                                            "
  echo "First let's look at our Iceberg environment, we are using Spark Shell so you can run these exact same commands in your own environment."
  echo -e "${NC}"
  echo ""
fi

if [ "$PARAGRAPH" = "test_1a_header" ]
then
  echo ""
  echo -e ""
  echo -e "${GREEN}"
  echo "Demo Part 1a:"
  echo " _____      _                              "
  echo "/  ___|    | |                             "
  echo "\ \`--.  ___| |__   ___ _ __ ___   __ _     "
  echo " \`--. \/ __| '_ \ / _ \ '_ \` _ \ / _\` |    "
  echo "/\__/ / (__| | | |  __/ | | | | | (_| |    "
  echo "\____/ \___|_| |_|\___|_| |_| |_|\__,_|    "
  echo "                                           "
  echo "                                           "
  echo " _____           _       _   _             "
  echo "|  ___|         | |     | | (_)            "
  echo "| |____   _____ | |_   _| |_ _  ___  _ __  "
  echo "|  __\ \ / / _ \| | | | | __| |/ _ \| '_ \  "
  echo "| |___\ V / (_) | | |_| | |_| | (_) | | | |"
  echo "\____/ \_/ \___/|_|\__,_|\__|_|\___/|_| |_|"
  echo "                                           "
  echo "                                           "
  echo "Now let's look at how Streambased can handle schema evolution cases on the fly"
  echo -e "${NC}"
  echo ""
fi

if [ "$PARAGRAPH" = "test_2_header" ]
then
  echo ""
  echo -e ""
  echo -e "${GREEN}"
  echo "Demo Part 2:"
  echo " _____         _                              "
  echo "|_   _|       | |                             "
  echo "  | |  ___ ___| |__   ___ _ __ __ _           "
  echo "  | | / __/ _ \ '_ \ / _ \ '__/ _\` |          "
  echo " _| || (_|  __/ |_) |  __/ | | (_| |          "
  echo " \___/\___\___|_.__/ \___|_|  \__, |          "
  echo "                               __/ |          "
  echo "                              |___/           "
  echo " _____                      _   _             "
  echo "|_   _|                    | | (_)            "
  echo "  | | _ __   __ _  ___  ___| |_ _  ___  _ __  "
  echo "  | || '_ \ / _\` |/ _ \/ __| __| |/ _ \| '_ \ "
  echo " _| || | | | (_| |  __/\__ \ |_| | (_) | | | |"
  echo " \___/_| |_|\__, |\___||___/\__|_|\___/|_| |_|"
  echo "             __/ |                            "
  echo "            |___/                             "
  echo "Now let's look at how Streambased can help transfer data from Kafka to Iceberg"
  echo -e "${NC}"
  echo ""
fi

if [ "$PARAGRAPH" = "test_3_header" ]
then
  echo ""
  echo -e ""
  echo -e "${GREEN}"
  echo "Demo Part 3:"
  echo " _____         _                          __     _   __       __ _         "
  echo "|_   _|       | |                         \ \   | | / /      / _| |        "
  echo "  | |  ___ ___| |__   ___ _ __ __ _   _____\ \  | |/ /  __ _| |_| | ____ _ "
  echo "  | | / __/ _ \ '_ \ / _ \ '__/ _\` | |______> > |    \ / _\` |  _| |/ / _\` |"
  echo " _| || (_|  __/ |_) |  __/ | | (_| |       / /  | |\  \ (_| | | |   < (_| |"
  echo " \___/\___\___|_.__/ \___|_|  \__, |      /_/   \_| \_/\__,_|_| |_|\_\__,_|"
  echo "                               __/ |                                       "
  echo "                              |___/                                        "
  echo ""
  echo "Now let's read Iceberg data from Kafka clients..."
  echo -e "${NC}"
  echo ""
fi

if [ "$PARAGRAPH" = "complete" ]
then
  echo ""
  echo -e ""
  echo -e "${GREEN}"
  echo "______                       _____                       _      _       "
  echo "|  _  \                     /  __ \                     | |    | |      "
  echo "| | | |___ _ __ ___   ___   | /  \/ ___  _ __ ___  _ __ | | ___| |_ ___ "
  echo "| | | / _ \ '_ \` _ \ / _ \  | |    / _ \| '_ \` _ \| '_ \| |/ _ \ __/ _ \ "
  echo "| |/ /  __/ | | | | | (_) | | \__/\ (_) | | | | | | |_) | |  __/ ||  __/"
  echo "|___/ \___|_| |_| |_|\___/   \____/\___/|_| |_| |_| .__/|_|\___|\__\___|"
  echo "                                                  | |                   "
  echo "                                                  |_|                   "
  echo -e "${NC}"
  echo ""
fi