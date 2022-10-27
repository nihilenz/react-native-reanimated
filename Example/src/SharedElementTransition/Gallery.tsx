import * as React from 'react';
import {
  View,
  Image,
  Text,
  StyleSheet,
  Pressable,
  Dimensions,
} from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import Animated, { FadeIn } from 'react-native-reanimated';

const florence = require('./assets/florence.jpg');
const countryside = require('./assets/countryside.jpg');
const dawn = require('./assets/dawn.jpg');

type StackParamList = {
  Home: undefined;
  Details: { tag: Tag };
};

const Stack = createNativeStackNavigator<StackParamList>();
const AnimatedImage = Animated.createAnimatedComponent(Image);
const AnimatedText = Animated.createAnimatedComponent(Text);

const gallery = {
  florence: {
    image: florence,
    title: 'Beautiful city of Florence',
    description:
      'Florence was a centre of medieval European trade and finance and one of the wealthiest cities of that era.',
  },
  countryside: {
    image: countryside,
    title: 'Tuscan countryside',
    description:
      "Tuscany's picturesque hills attract millions of tourists each year craving postcard-perfect views.",
  },
  dawn: {
    image: dawn,
    title: 'Tuscany at dawn',
    description:
      'Tuscany is known for its magical mists in the morning and at sunset.',
  },
};

type Tag = keyof typeof gallery;

function HomeScreen({
  navigation,
}: NativeStackScreenProps<StackParamList, 'Home'>) {
  const chips = ['Italy', 'Tourism', 'Nature'];
  const goToDetails = (tag: Tag) => {
    navigation.navigate('Details', { tag });
  };

  const { width } = Dimensions.get('screen');

  return (
    <Animated.ScrollView style={styles.homeContainer}>
      <Pressable onPress={() => goToDetails('countryside')}>
        <AnimatedImage
          sharedTransitionTag={'countryside'}
          source={gallery.countryside.image}
          style={{
            width: '100%',
            height: 160,
            marginTop: 20,
            borderRadius: 15,
          }}
        />
      </Pressable>
      <View style={styles.row}>
        <Pressable onPress={() => goToDetails('florence')}>
          <AnimatedImage
            sharedTransitionTag={'florence'}
            source={gallery.florence.image}
            style={{
              width: width / 2 - 35,
              height: 250,
              marginTop: 20,
              borderRadius: 15,
            }}
          />
        </Pressable>
        <Pressable onPress={() => goToDetails('dawn')}>
          <AnimatedImage
            sharedTransitionTag={'dawn'}
            source={gallery.dawn.image}
            style={{
              width: width / 2 - 35,
              height: 250,
              marginTop: 20,
              marginLeft: 20,
              borderRadius: 15,
            }}
          />
        </Pressable>
      </View>
      <Text style={{ ...styles.header, fontSize: 40 }}>Tuscany</Text>
      <View style={styles.row}>
        {chips.map((chip) => (
          <Text key={chip} style={styles.chip}>
            {chip}
          </Text>
        ))}
      </View>
      <Text style={styles.text}>
        Tuscany is known for its landscapes, history, artistic legacy, and its
        influence on high culture. It is regarded as the birthplace of the
        Italian Renaissance and of the foundations of the Italian language.
      </Text>
    </Animated.ScrollView>
  );
}

function DetailsScreen({
  route,
  navigation,
}: NativeStackScreenProps<StackParamList, 'Details'>) {
  const { tag } = route.params;

  return (
    <View style={styles.detailContainer}>
      <AnimatedImage
        sharedTransitionTag={tag}
        source={gallery[tag].image}
        style={styles.detailsImage}
      />
      <View style={styles.wrapper}>
        <AnimatedText
          entering={FadeIn.delay(150).duration(1000)}
          style={{ ...styles.header, fontSize: 28 }}>
          {gallery[tag].title}
        </AnimatedText>
        <AnimatedText
          entering={FadeIn.delay(300).duration(1000)}
          style={styles.text}>
          {gallery[tag].description}
        </AnimatedText>
        <Animated.View
          entering={FadeIn.delay(500).duration(1000)}
          style={styles.callToActionWrapper}>
          <Pressable
            style={styles.callToAction}
            onPress={() => navigation.goBack()}>
            <Text style={styles.callToActionText}>see for yourself</Text>
          </Pressable>
        </Animated.View>
      </View>
    </View>
  );
}

export default function Gallery() {
  return (
    <NavigationContainer>
      <Stack.Navigator
        screenOptions={{
          headerShown: false,
        }}>
        <Stack.Screen name="Home" component={HomeScreen} />
        <Stack.Screen name="Details" component={DetailsScreen} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}

const styles = StyleSheet.create({
  homeContainer: {
    flex: 1,
    marginHorizontal: 25,
    marginTop: 50,
  },
  detailContainer: {
    flex: 1,
  },
  wrapper: {
    flex: 1,
    marginHorizontal: 25,
  },
  row: {
    flexDirection: 'row',
  },
  header: {
    fontSize: 40,
    fontWeight: 'bold',
    marginTop: 25,
    marginBottom: 12,
  },
  text: {
    fontSize: 16,
    marginTop: 8,
  },
  chip: {
    borderWidth: 1,
    borderColor: '#ccc',
    padding: 8,
    width: 90,
    borderRadius: 5,
    textAlign: 'center',
    marginRight: 8,
  },
  detailsImage: {
    width: '100%',
    height: 500,
  },
  callToActionWrapper: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 30,
  },
  callToAction: {
    backgroundColor: '#add8e6',
    padding: 16,
    width: 250,
    borderRadius: 5,
  },
  callToActionText: {
    color: '#015571',
    textAlign: 'center',
    textTransform: 'uppercase',
    fontSize: 16,
    fontWeight: 'bold',
  },
});
